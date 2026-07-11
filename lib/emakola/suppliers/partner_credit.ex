defmodule Emakola.Suppliers.PartnerCredit do
  @moduledoc "Provider-funded trade credit, consented explicitly and repaid only from realized sales."
  require Ash.Query

  alias Emakola.Suppliers.{
    CommercePassport,
    PartnerCreditAgreement,
    PartnerCreditOffer,
    PartnerCreditRepayment
  }

  @tiers %{starter: 0, reliable: 1, proven: 2}

  def create_offer(actor, attrs) do
    with :ok <- validate_terms(attrs),
         :ok <- authorize_provider(actor, attrs) do
      PartnerCreditOffer
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create(authorize?: false)
    end
  end

  def accept(actor, offer_id, consent?) do
    with true <- consent? == true,
         {:ok, offer} <- Ash.get(PartnerCreditOffer, offer_id, authorize?: false),
         :ok <- ensure_store_access(actor, offer.borrower_store_id),
         true <- offer.status == :offered,
         passport when not is_nil(passport) <- current_passport(offer.borrower_store_id),
         true <- @tiers[passport.tier] >= @tiers[offer.minimum_tier] do
      total = offer.principal_amount + offer.fee_amount

      snapshot = %{
        "provider_name" => offer.provider_name,
        "provider_type" => to_string(offer.provider_type),
        "principal_amount" => offer.principal_amount,
        "fee_amount" => offer.fee_amount,
        "total_due" => total,
        "repayment_bps" => offer.repayment_bps,
        "term_days" => offer.term_days,
        "reason_code" => offer.reason_code,
        "passport_tier" => to_string(passport.tier),
        "consent" => true
      }

      Emakola.Repo.transaction(fn ->
        agreement =
          PartnerCreditAgreement
          |> Ash.Changeset.for_create(:create, %{
            offer_id: offer.id,
            borrower_store_id: offer.borrower_store_id,
            passport_id: passport.id,
            principal_amount: offer.principal_amount,
            fee_amount: offer.fee_amount,
            total_due: total,
            outstanding_amount: total,
            repayment_bps: offer.repayment_bps,
            consent_snapshot: snapshot,
            consented_at: DateTime.utc_now()
          })
          |> Ash.create!(authorize?: false)

        offer |> Ash.Changeset.for_update(:accept, %{}) |> Ash.update!(authorize?: false)
        agreement
      end)
      |> normalize()
    else
      false -> {:error, :informed_consent_or_eligibility_required}
      nil -> {:error, :current_passport_required}
      error -> error
    end
  end

  def activate(actor, agreement_id, reference) when is_binary(reference) do
    with true <- String.trim(reference) != "",
         {:ok, agreement} <- Ash.get(PartnerCreditAgreement, agreement_id, authorize?: false),
         {:ok, offer} <- Ash.get(PartnerCreditOffer, agreement.offer_id, authorize?: false),
         :ok <- authorize_provider(actor, Map.from_struct(offer)) do
      agreement
      |> Ash.Changeset.for_update(:activate, %{
        external_disbursement_reference: String.trim(reference),
        activated_at: DateTime.utc_now()
      })
      |> Ash.update(authorize?: false)
    else
      false -> {:error, :disbursement_evidence_required}
      error -> error
    end
  end

  def carve_sales_proceeds(allocations, borrower_store_id) do
    case active_agreement(borrower_store_id) do
      nil ->
        allocations

      agreement ->
        Enum.flat_map(allocations, fn
          %{role: role, recipient_store_id: ^borrower_store_id, amount: amount} = allocation
          when role in [:merchant, :dropshipper] ->
            repayment =
              min(agreement.outstanding_amount, div(amount * agreement.repayment_bps, 10_000))

            if repayment > 0 do
              offer = Ash.get!(PartnerCreditOffer, agreement.offer_id, authorize?: false)

              [
                %{allocation | amount: amount - repayment},
                %{
                  role: :credit_partner,
                  recipient_store_id: offer.provider_store_id,
                  amount: repayment,
                  subaccount_code: offer.creditor_subaccount_code,
                  credit_agreement_id: agreement.id
                }
              ]
            else
              [allocation]
            end

          allocation ->
            [allocation]
        end)
    end
  end

  def record_settlement(payment, splits) do
    Enum.each(Enum.filter(splits, &(&1.role == :credit_partner)), fn split ->
      Emakola.Repo.transaction(fn ->
        case repayment(split.credit_agreement_id, payment.id) do
          nil ->
            agreement =
              Ash.get!(PartnerCreditAgreement, split.credit_agreement_id, authorize?: false)

            PartnerCreditRepayment
            |> Ash.Changeset.for_create(:create, %{
              agreement_id: agreement.id,
              payment_id: payment.id,
              amount: split.amount
            })
            |> Ash.create!(authorize?: false)

            set_balance(agreement, max(0, agreement.outstanding_amount - split.amount))

          _ ->
            :ok
        end
      end)
    end)

    :ok
  end

  def reconcile_refund(payment, splits) do
    Enum.each(Enum.filter(splits, &(&1.role == :credit_partner)), fn split ->
      case repayment(split.credit_agreement_id, payment.id) do
        nil ->
          :ok

        item ->
          target = min(item.amount, div(item.amount * payment.refunded_amount, payment.amount))
          delta = max(0, target - item.reversed_amount)

          if delta > 0 do
            agreement = Ash.get!(PartnerCreditAgreement, item.agreement_id, authorize?: false)

            item
            |> Ash.Changeset.for_update(:reverse, %{reversed_amount: target})
            |> Ash.update!(authorize?: false)

            set_balance(agreement, min(agreement.total_due, agreement.outstanding_amount + delta))
          end
      end
    end)

    :ok
  end

  defp validate_terms(a) do
    cond do
      a[:provider_type] == :licensed_partner and blank?(a[:license_reference]) ->
        {:error, :license_reference_required}

      a[:provider_type] == :supplier and is_nil(a[:provider_store_id]) ->
        {:error, :supplier_store_required}

      a[:principal_amount] <= 0 or a[:fee_amount] < 0 ->
        {:error, :invalid_amounts}

      a[:repayment_bps] < 1 or a[:repayment_bps] > 10_000 ->
        {:error, :invalid_repayment_rate}

      true ->
        :ok
    end
  end

  defp authorize_provider(actor, %{provider_type: :supplier, provider_store_id: id}),
    do: ensure_store_access(actor, id)

  defp authorize_provider(%Emakola.Accounts.Merchant{}, %{provider_type: :licensed_partner}),
    do: :ok

  defp authorize_provider(_, _), do: {:error, :forbidden}

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> case do
      [_] -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_, _), do: {:error, :forbidden}

  defp current_passport(store_id),
    do:
      CommercePassport
      |> Ash.Query.filter(store_id == ^store_id and expires_at > ^DateTime.utc_now())
      |> Ash.read_one!(authorize?: false)

  defp active_agreement(store_id),
    do:
      PartnerCreditAgreement
      |> Ash.Query.filter(
        borrower_store_id == ^store_id and status == :active and outstanding_amount > 0
      )
      |> Ash.Query.sort(activated_at: :asc)
      |> Ash.read_one!(authorize?: false)

  defp repayment(agreement_id, payment_id),
    do:
      PartnerCreditRepayment
      |> Ash.Query.filter(agreement_id == ^agreement_id and payment_id == ^payment_id)
      |> Ash.read_one!(authorize?: false)

  defp set_balance(agreement, amount),
    do:
      agreement
      |> Ash.Changeset.for_update(:balance, %{
        outstanding_amount: amount,
        status: if(amount == 0, do: :repaid, else: :active)
      })
      |> Ash.update!(authorize?: false)

  defp blank?(value), do: is_nil(value) or String.trim(value) == ""
  defp normalize({:ok, value}), do: {:ok, value}
  defp normalize({:error, reason}), do: {:error, reason}
end
