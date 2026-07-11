defmodule Emakola.Suppliers.ProtectedPreorders do
  @moduledoc "Approval-gated preorder deposits with disclosed milestones and automatic failure refunds."
  require Ash.Query

  alias Emakola.Suppliers.{
    CommercePassport,
    PreorderDeposit,
    PreorderMilestone,
    ProtectedPreorder,
    ReputationSignal
  }

  def create(actor, store_id, attrs, milestones) when is_list(milestones) do
    with :ok <- ensure_store_access(actor, store_id),
         :ok <- validate_plan(attrs, milestones) do
      Emakola.Repo.transaction(fn ->
        preorder =
          ProtectedPreorder
          |> Ash.Changeset.for_create(:create, Map.put(attrs, :supplier_store_id, store_id))
          |> Ash.create!(authorize?: false)

        milestones
        |> Enum.with_index(1)
        |> Enum.each(fn {m, position} ->
          PreorderMilestone
          |> Ash.Changeset.for_create(
            :create,
            Map.merge(m, %{preorder_id: preorder.id, position: position})
          )
          |> Ash.create!(authorize?: false)
        end)

        Ash.load!(preorder, :milestones, authorize?: false)
      end)
      |> normalize()
    end
  end

  def open(actor, store_id, id) do
    with {:ok, preorder} <- authorized(actor, store_id, id),
         :ok <- approvals_present(preorder),
         true <- preorder.status == :draft do
      case preorder |> Ash.Changeset.for_update(:open, %{}) |> Ash.update(authorize?: false) do
        {:ok, opened} -> {:ok, Ash.load!(opened, :milestones, authorize?: false)}
        error -> error
      end
    else
      false -> {:error, :invalid_status}
      error -> error
    end
  end

  def reserve(id, customer, quantity) when is_integer(quantity) and quantity > 0 do
    Emakola.Repo.transaction(fn ->
      preorder = locked_preorder!(id)

      with :ok <- collectable(preorder, quantity),
           true <- customer.store_id == preorder.supplier_store_id do
        PreorderDeposit
        |> Ash.Changeset.for_create(:create, %{
          preorder_id: id,
          store_id: preorder.supplier_store_id,
          customer_id: customer.id,
          quantity: quantity,
          amount: preorder.deposit_amount * quantity
        })
        |> Ash.create!(authorize?: false)
      else
        false -> Emakola.Repo.rollback(:forbidden)
        {:error, reason} -> Emakola.Repo.rollback(reason)
      end
    end)
    |> normalize()
  end

  def initiate_deposit(id, customer, quantity, callback_url) do
    with {:ok, deposit} <- reserve(id, customer, quantity),
         {:ok, preorder} <- Ash.get(ProtectedPreorder, id, authorize?: false),
         {:ok, response} <-
           payment_gateway().initiate_payment(%{
             amount: deposit.amount,
             email: customer.email,
             currency: "GHS",
             store_id: preorder.supplier_store_id,
             callback_url: callback_url,
             return_url: callback_url,
             metadata: %{preorder_deposit_id: deposit.id}
           }),
         {:ok, payment} <-
           Emakola.Payments.create_payment(
             %{
               store_id: preorder.supplier_store_id,
               amount: deposit.amount,
               currency: "GHS",
               gateway: :paystack,
               gateway_reference: response.reference,
               customer_email: customer.email,
               metadata: %{preorder_deposit_id: deposit.id},
               payout_held: true,
               payout_hold_reason: "protected_preorder_deposit"
             },
             authorize?: false
           ),
         {:ok, attached} <-
           deposit
           |> Ash.Changeset.for_update(:attach_payment, %{payment_id: payment.id})
           |> Ash.update(authorize?: false) do
      {:ok, %{deposit: attached, payment: payment, authorization_url: response.authorization_url}}
    end
  end

  def confirm_payment(payment) do
    case PreorderDeposit
         |> Ash.Query.filter(payment_id == ^payment.id)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        :ok

      %{status: :pending} = deposit ->
        preorder = Ash.get!(ProtectedPreorder, deposit.preorder_id, authorize?: false)

        if payment.status == :success and payment.amount == deposit.amount do
          deposit |> Ash.Changeset.for_update(:paid, %{}) |> Ash.update!(authorize?: false)

          preorder
          |> Ash.Changeset.for_update(:record_quantity, %{quantity: deposit.quantity})
          |> Ash.update!(authorize?: false)

          refresh_funding(preorder.id)
        end

        :ok

      %{status: :paid} ->
        :ok

      _ ->
        :ok
    end
  end

  def complete_milestone(actor, store_id, milestone_id, evidence) when is_map(evidence) do
    with {:ok, milestone} <- Ash.get(PreorderMilestone, milestone_id, authorize?: false),
         {:ok, preorder} <- authorized(actor, store_id, milestone.preorder_id),
         true <- map_size(evidence) > 0 and milestone.status == :pending do
      completed =
        milestone
        |> Ash.Changeset.for_update(:complete, %{
          evidence: evidence,
          completed_at: DateTime.utc_now()
        })
        |> Ash.update!(authorize?: false)

      refresh_production(preorder.id)
      {:ok, completed}
    else
      false -> {:error, :evidence_required}
      error -> error
    end
  end

  def fulfill(actor, store_id, id) do
    with {:ok, preorder} <- authorized(actor, store_id, id),
         true <- preorder.status in [:funded, :production],
         milestones <-
           PreorderMilestone
           |> Ash.Query.filter(preorder_id == ^id)
           |> Ash.read!(authorize?: false),
         true <- milestones != [] and Enum.all?(milestones, &(&1.status == :completed)) do
      Emakola.Repo.transaction(fn ->
        PreorderDeposit
        |> Ash.Query.filter(preorder_id == ^id and status == :paid)
        |> Ash.read!(authorize?: false)
        |> Enum.each(fn deposit ->
          payment = Ash.get!(Emakola.Payments.Payment, deposit.payment_id, authorize?: false)

          payment
          |> Ash.Changeset.for_update(:release_payout_hold, %{})
          |> Ash.update!(authorize?: false)
        end)

        preorder
        |> Ash.Changeset.for_update(:status, %{status: :fulfilled})
        |> Ash.update!(authorize?: false)
      end)
      |> normalize()
    else
      false -> {:error, :all_milestones_must_be_completed}
      error -> error
    end
  end

  def fail_and_refund(id, reason, gateway \\ payment_gateway()) do
    preorder = Ash.get!(ProtectedPreorder, id, authorize?: false)

    with true <- failure_due?(preorder) do
      first_failure? = preorder.status not in [:failed, :refunded]

      failed =
        preorder
        |> Ash.Changeset.for_update(:status, %{
          status: :failed,
          failed_at: DateTime.utc_now(),
          failure_reason: reason
        })
        |> Ash.update!(authorize?: false)

      mark_overdue_milestones(failed.id)
      if first_failure?, do: record_performance_consequence(failed, reason)

      deposits =
        PreorderDeposit
        |> Ash.Query.filter(preorder_id == ^id and status in [:paid, :refunding, :refund_failed])
        |> Ash.read!(authorize?: false)

      results = Enum.map(deposits, &refund(&1, gateway))

      remaining =
        PreorderDeposit
        |> Ash.Query.filter(preorder_id == ^id and status in [:paid, :refunding, :refund_failed])
        |> Ash.read!(authorize?: false)

      if remaining == [],
        do:
          failed
          |> Ash.Changeset.for_update(:status, %{status: :refunded})
          |> Ash.update!(authorize?: false)

      {:ok, results}
    else
      false -> {:error, :failure_not_due}
    end
  end

  def due_for_failure?(preorder), do: failure_due?(preorder)

  defp refund(deposit, gateway) do
    payment = Ash.get!(Emakola.Payments.Payment, deposit.payment_id, authorize?: false)

    if payment.status == :refunded do
      # Money already moved (e.g. crash after the gateway call) — finish the
      # bookkeeping without touching the gateway again.
      deposit
      |> claim_unless_refunding()
      |> Ash.Changeset.for_update(:refunded, %{refund_reference: nil})
      |> Ash.update!(authorize?: false)

      {:ok, deposit.id}
    else
      execute_refund(claim_unless_refunding(deposit), payment, gateway)
    end
  end

  defp claim_unless_refunding(%{status: :refunding} = deposit), do: deposit

  defp claim_unless_refunding(deposit) do
    deposit
    |> Ash.Changeset.for_update(:claim_refund, %{refund_claimed_at: DateTime.utc_now()})
    |> Ash.update!(authorize?: false)
  end

  defp execute_refund(claimed, payment, gateway) do
    case gateway.process_refund(payment.gateway_reference, claimed.amount) do
      {:ok, response} ->
        reference = response[:refund_reference] || response["refund_reference"]

        payment
        |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: claimed.amount})
        |> Ash.update!(authorize?: false)

        claimed
        |> Ash.Changeset.for_update(:refunded, %{refund_reference: reference})
        |> Ash.update!(authorize?: false)

        {:ok, claimed.id}

      {:error, reason} ->
        claimed
        |> Ash.Changeset.for_update(:refund_failed, %{
          refund_error: inspect(reason) |> String.slice(0, 500)
        })
        |> Ash.update!(authorize?: false)

        {:error, claimed.id, reason}
    end
  end

  defp validate_plan(a, milestones) do
    disclosures = a[:customer_disclosures] || %{}

    cond do
      a[:deposit_amount] <= 0 or a[:deposit_amount] > a[:unit_price] ->
        {:error, :invalid_deposit}

      a[:minimum_quantity] < 1 or a[:maximum_quantity] < a[:minimum_quantity] ->
        {:error, :invalid_demand}

      Date.compare(a[:delivery_window_end], a[:delivery_window_start]) == :lt ->
        {:error, :invalid_delivery_window}

      DateTime.compare(a[:automatic_refund_deadline], a[:commitment_deadline]) == :lt ->
        {:error, :invalid_refund_deadline}

      milestones == [] ->
        {:error, :milestones_required}

      not Enum.all?(
        ["deposit_treatment", "automatic_refund_rule", "delivery_window", "supplier_identity"],
        &Map.has_key?(disclosures, &1)
      ) ->
        {:error, :complete_disclosures_required}

      true ->
        :ok
    end
  end

  defp approvals_present(p) do
    if present?(p.legal_approval_reference) and present?(p.payment_provider_approval_reference),
      do: :ok,
      else: {:error, :funds_flow_not_approved}
  end

  defp collectable(p, quantity) do
    cond do
      p.status != :open ->
        {:error, :preorder_closed}

      DateTime.compare(DateTime.utc_now(), p.commitment_deadline) != :lt ->
        {:error, :preorder_closed}

      p.committed_quantity + pending_quantity(p.id) + quantity > p.maximum_quantity ->
        {:error, :quantity_exceeds_remaining}

      true ->
        approvals_present(p)
    end
  end

  defp pending_quantity(id),
    do:
      PreorderDeposit
      |> Ash.Query.filter(preorder_id == ^id and status == :pending)
      |> Ash.read!(authorize?: false)
      |> Enum.sum_by(& &1.quantity)

  defp refresh_funding(id) do
    p = Ash.get!(ProtectedPreorder, id, authorize?: false)

    if p.committed_quantity >= p.minimum_quantity and p.status == :open,
      do:
        p
        |> Ash.Changeset.for_update(:status, %{status: :funded})
        |> Ash.update!(authorize?: false)
  end

  defp refresh_production(id) do
    p = Ash.get!(ProtectedPreorder, id, authorize?: false)

    if p.status == :funded,
      do:
        p
        |> Ash.Changeset.for_update(:status, %{status: :production})
        |> Ash.update!(authorize?: false)
  end

  defp failure_due?(p),
    do:
      (p.status in [:open, :funded, :production] and
         (DateTime.compare(DateTime.utc_now(), p.automatic_refund_deadline) in [:eq, :gt] or
            overdue_milestone?(p.id))) or
        (p.status in [:failed, :refunded] and refundable_deposits?(p.id))

  defp refundable_deposits?(id),
    do:
      PreorderDeposit
      |> Ash.Query.filter(preorder_id == ^id and status in [:paid, :refunding, :refund_failed])
      |> Ash.exists?(authorize?: false)

  defp overdue_milestone?(id),
    do:
      PreorderMilestone
      |> Ash.Query.filter(
        preorder_id == ^id and status == :pending and due_at < ^DateTime.utc_now()
      )
      |> Ash.exists?(authorize?: false)

  defp mark_overdue_milestones(id),
    do:
      PreorderMilestone
      |> Ash.Query.filter(
        preorder_id == ^id and status == :pending and due_at < ^DateTime.utc_now()
      )
      |> Ash.read!(authorize?: false)
      |> Enum.each(
        &(&1
          |> Ash.Changeset.for_update(:miss, %{})
          |> Ash.update!(authorize?: false))
      )

  defp record_performance_consequence(p, reason) do
    case CommercePassport
         |> Ash.Query.filter(store_id == ^p.supplier_store_id)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        :ok

      passport ->
        now = DateTime.utc_now()

        ReputationSignal
        |> Ash.Changeset.for_create(:create, %{
          passport_id: passport.id,
          store_id: p.supplier_store_id,
          kind: :service_quality,
          value: 0,
          impact: -100,
          reason_code: "PREORDER_MILESTONE_FAILURE",
          evidence: %{"preorder_id" => p.id, "reason" => reason},
          source_fingerprint: "preorder-failure-#{p.id}",
          observed_at: now,
          expires_at: DateTime.add(now, 90, :day)
        })
        |> Ash.create!(authorize?: false)
    end
  end

  defp authorized(actor, store_id, id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, p} <- Ash.get(ProtectedPreorder, id, authorize?: false),
         true <- p.supplier_store_id == store_id,
         do: {:ok, p},
         else: (
           false -> {:error, :forbidden}
           error -> error
         )
  end

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: actor_id}, store_id),
    do:
      if(
        Emakola.Accounts.StoreMembership
        |> Ash.Query.filter(merchant_id == ^actor_id and store_id == ^store_id)
        |> Ash.exists?(authorize?: false),
        do: :ok,
        else: {:error, :forbidden}
      )

  defp ensure_store_access(_, _), do: {:error, :forbidden}

  defp locked_preorder!(id),
    do:
      ProtectedPreorder
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read_one!(authorize?: false)

  defp present?(v), do: is_binary(v) and String.trim(v) != ""

  defp payment_gateway,
    do: Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)

  defp normalize({:ok, value}), do: {:ok, value}
  defp normalize({:error, value}), do: {:error, value}
end
