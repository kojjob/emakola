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
         :ok <- ensure_no_open_agreement(offer.borrower_store_id),
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
        # Capacity excludes carves already routed on in-flight (pending)
        # payments, so overlapping checkouts cannot over-collect the debt.
        available = max(0, agreement.outstanding_amount - pending_carved(agreement.id))

        Enum.flat_map(allocations, fn
          %{role: role, recipient_store_id: ^borrower_store_id, amount: amount} = allocation
          when role in [:merchant, :dropshipper] ->
            # Folded unlinked-supplier passthrough money (internal rail only)
            # is owed manually to the supplier — it is not the borrower's
            # sales proceeds, so it is excluded from the repayment base.
            repayment_base = amount - Map.get(allocation, :passthrough_amount, 0)
            repayment = min(available, div(repayment_base * agreement.repayment_bps, 10_000))

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

  # Both settlement and refund reconciliation RECOMPUTE the outstanding balance
  # from the repayment ledger under a FOR UPDATE lock on the agreement — never
  # read-modify-write — so concurrent webhooks and crashed prior runs converge
  # on the ledger truth instead of losing updates.
  def record_settlement(payment, splits) do
    Enum.each(Enum.filter(splits, &(&1.role == :credit_partner)), fn split ->
      Emakola.Repo.transaction(fn ->
        agreement = locked_agreement!(split.credit_agreement_id)

        case repayment(agreement.id, payment.id) do
          nil ->
            PartnerCreditRepayment
            |> Ash.Changeset.for_create(:create, %{
              agreement_id: agreement.id,
              payment_id: payment.id,
              amount: split.amount
            })
            |> Ash.create!(authorize?: false)

            recompute_balance!(agreement)

          _ ->
            :ok
        end
      end)
    end)

    :ok
  end

  def reconcile_refund(payment, splits) do
    Enum.each(Enum.filter(splits, &(&1.role == :credit_partner)), fn split ->
      Emakola.Repo.transaction(fn ->
        agreement = locked_agreement!(split.credit_agreement_id)

        case repayment(agreement.id, payment.id) do
          nil ->
            :ok

          item ->
            target = min(item.amount, div(item.amount * payment.refunded_amount, payment.amount))

            if target > item.reversed_amount do
              item
              |> Ash.Changeset.for_update(:reverse, %{reversed_amount: target})
              |> Ash.update!(authorize?: false)
            end

            # Recompute unconditionally so a replay heals a crashed prior run
            # that recorded the reversal but lost the balance restore.
            recompute_balance!(agreement)
        end
      end)
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

  # Licensed-partner lending is platform-mediated: only platform staff may
  # register a licensed lender's offer. A merchant claiming to be a licensed
  # partner could otherwise divert borrower proceeds to their own subaccount.
  defp authorize_provider(%Emakola.Accounts.User{} = actor, %{provider_type: :licensed_partner}) do
    if Emakola.Accounts.PlatformPermissions.staff?(actor), do: :ok, else: {:error, :forbidden}
  end

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
      |> Ash.Query.limit(1)
      |> Ash.read!(authorize?: false)
      |> List.first()

  defp ensure_no_open_agreement(store_id) do
    PartnerCreditAgreement
    |> Ash.Query.filter(borrower_store_id == ^store_id and status in [:accepted, :active])
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> case do
      [] -> :ok
      _ -> {:error, :active_agreement_exists}
    end
  end

  defp locked_agreement!(agreement_id),
    do:
      PartnerCreditAgreement
      |> Ash.Query.filter(id == ^agreement_id)
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read_one!(authorize?: false)

  # In-flight carves: pending credit-partner splits younger than the TTL. The
  # TTL bounds starvation from abandoned checkouts (their splits never settle).
  @pending_carve_ttl_hours 24
  defp pending_carved(agreement_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -@pending_carve_ttl_hours, :hour)

    Emakola.Payments.PaymentSplit
    |> Ash.Query.filter(
      credit_agreement_id == ^agreement_id and role == :credit_partner and
        status == :pending and inserted_at > ^cutoff
    )
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(0, &(&1.amount + &2))
  end

  defp repayment(agreement_id, payment_id),
    do:
      PartnerCreditRepayment
      |> Ash.Query.filter(agreement_id == ^agreement_id and payment_id == ^payment_id)
      |> Ash.read_one!(authorize?: false)

  defp recompute_balance!(agreement) do
    repaid =
      PartnerCreditRepayment
      |> Ash.Query.filter(agreement_id == ^agreement.id)
      |> Ash.read!(authorize?: false)
      |> Enum.reduce(0, &(&1.amount - &1.reversed_amount + &2))

    amount = agreement.total_due |> Kernel.-(repaid) |> max(0) |> min(agreement.total_due)

    agreement
    |> Ash.Changeset.for_update(:balance, %{
      outstanding_amount: amount,
      status: if(amount == 0, do: :repaid, else: :active)
    })
    |> Ash.update!(authorize?: false)
  end

  defp blank?(value), do: is_nil(value) or String.trim(value) == ""
  defp normalize({:ok, value}), do: {:ok, value}
  defp normalize({:error, reason}), do: {:error, reason}
end
