defmodule Emakola.Payments.Workers.PaystackWebhookHandler do
  @moduledoc """
  Oban worker that processes Paystack webhook events — the single authority
  for Paystack webhook handling. Enqueued by `EmakolaWeb.WebhookController`
  after HMAC verification by `Emakola.Payments.Gateways.Paystack`.

  Handles:
  - charge.success — marks payment success, confirms order, settles dropship
    splits, broadcasts to polling LiveViews
  - charge.failed — marks payment failed, broadcasts
  - refund.processed — marks payment refunded, reverses splits, closes a
    :held buyer-protection hold once fully refunded, broadcasts
  - transfer.success / transfer.failed / transfer.reversed — finalizes merchant payouts
  - settlement / settlement.success — reconciles splits against the paid-out
    batch: fetches the settlement's transaction list and stamps
    paystack_split_reference on the splits routed to that destination

  Idempotent: deduplicated at insert time (24h unique window) and guarded by a
  terminal-state check inside `perform/1`.
  """

  use Oban.Worker,
    queue: :webhooks,
    max_attempts: 5,
    # Paystack replays the same payload on retry. Deduplicate at insert
    # time within a 24h window — `Oban.insert!/1` returns the existing
    # job rather than creating a duplicate. The terminal-state guard
    # inside perform/1 remains as defense-in-depth for non-identical
    # jobs that happen to converge on the same payment.
    unique: [period: 86_400, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Payments.{Payment, ProtectionHolds}

  @terminal_states [:success, :failed, :refunded]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => event, "data" => data}}) do
    case event do
      "charge.success" ->
        handle_charge_success(data)

      "charge.failed" ->
        handle_charge_failed(data)

      "refund.processed" ->
        handle_refund_processed(data)

      "transfer.success" ->
        finalize_payout(data, :paid)

      "transfer.failed" ->
        finalize_payout(data, :failed)

      "transfer.reversed" ->
        finalize_payout(data, :reversed)

      # A settlement batch was paid out. These used to fall through to the
      # unknown-event clause and be silently dropped, so :settled stayed the
      # ledger's last word — "charge accepted", never "money actually moved".
      "settlement" ->
        handle_settlement(data)

      "settlement.success" ->
        handle_settlement(data)

      _unknown ->
        Logger.warning("[paystack_webhook] unhandled event: #{inspect(event)}")
        :ok
    end
  end

  # Finalize a merchant payout from a transfer webhook. `data["reference"]` is the
  # payout's transfer_reference. Unknown references (transfers not initiated by us)
  # are ignored.
  defp finalize_payout(data, outcome) do
    case Emakola.Payments.get_payout_by_transfer_reference(data["reference"],
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, %{} = payout} -> reconcile_payout(payout, outcome, data)
      _ -> :ok
    end
  end

  # Drive a payout to its terminal state from a transfer webhook, idempotently.
  # `release_payout_balance/1` is always safe to re-run (it returns [] once the
  # charges are released or re-claimed by a fresh payout), so a retry after a
  # crash mid-release — or a webhook replay — still completes without burying
  # the balance.

  # A reversal AFTER a success: the gateway clawed the money back, so un-pay the
  # payout and return the balance — the one path out of :paid.
  defp reconcile_payout(%{status: :paid} = payout, :reversed, data) do
    {:ok, _} =
      Emakola.Payments.mark_payout_reversed(
        payout,
        %{failure_reason: "transfer reversed", gateway_response: data},
        authorize?: false
      )

    release_payout_balance(payout)
    :ok
  end

  # Otherwise :paid is terminal (idempotent success replay).
  defp reconcile_payout(%{status: :paid}, _outcome, _data), do: :ok

  # :failed / :reversed are terminal for money-movement, but RE-RUN the release so
  # an attempt that crashed mid-loop still returns every covered charge.
  defp reconcile_payout(%{status: status} = payout, _outcome, _data)
       when status in [:failed, :reversed] do
    release_payout_balance(payout)
    :ok
  end

  defp reconcile_payout(payout, :paid, data) do
    {:ok, _} =
      Emakola.Payments.mark_payout_paid(payout, %{gateway_response: data}, authorize?: false)

    if payout.basis == :allocations do
      mark_supplier_ledger_entries_paid(payout)
    end

    Emakola.Notifications.Workers.PayoutNotificationWorker.enqueue(payout.id)
    :ok
  end

  defp reconcile_payout(payout, :reversed, data) do
    {:ok, _} =
      Emakola.Payments.mark_payout_reversed(
        payout,
        %{failure_reason: "transfer reversed", gateway_response: data},
        authorize?: false
      )

    release_payout_balance(payout)
    :ok
  end

  defp reconcile_payout(payout, _failed, data) do
    {:ok, _} =
      Emakola.Payments.mark_payout_failed(
        payout,
        %{failure_reason: data["status"] || "transfer failed", gateway_response: data},
        authorize?: false
      )

    release_payout_balance(payout)
    :ok
  end

  defp release_payout_balance(payout) do
    {:ok, payments} = Emakola.Payments.list_payments_by_payout(payout.id, authorize?: false)

    Enum.each(payments, fn payment ->
      payment
      |> Ash.Changeset.for_update(:release_from_payout, %{})
      |> Ash.update!(authorize?: false)
    end)

    # Allocation-basis payouts claimed PaymentSplit rows instead; release those
    # too. Each list is empty for the other basis, so both loops are safe to
    # run unconditionally — same idempotent-replay contract as above. Rows are
    # re-read fresh via by_payout (never stale structs — see design spec §4.4).
    {:ok, splits} = Emakola.Payments.list_payment_splits_by_payout(payout.id, authorize?: false)

    Enum.each(splits, fn split ->
      {:ok, _} = Emakola.Payments.release_payment_split_from_payout(split, authorize?: false)
    end)
  end

  defp handle_charge_success(data) do
    reference = data["reference"]

    with {:ok, payment} <- find_payment(reference),
         :ok <- verify_amount(payment, data) do
      payment =
        case payment.status do
          # Already success (webhook retry/replay) — fall through to the idempotent
          # post-processing below so a prior PARTIAL failure (e.g. settle_splits
          # raised mid-loop) is recovered rather than skipped.
          :success ->
            payment

          # A late charge.success after a terminal failure/refund — don't override.
          s when s in [:failed, :refunded] ->
            payment

          _ ->
            updated =
              payment
              |> Ash.Changeset.for_update(:mark_success, %{gateway_response: data})
              |> Ash.update!(authorize?: false)

            Phoenix.PubSub.broadcast(
              Emakola.PubSub,
              "payment:#{reference}",
              {:payment_succeeded, reference, updated}
            )

            updated
        end

      # Idempotent post-processing — runs on every (re)delivery of a successful
      # charge. settle_splits only touches :pending splits and maybe_confirm_order
      # only a :pending order, so a retry safely completes a partial first attempt.
      if payment.status == :success do
        maybe_confirm_order(payment.order_id)
        payment.order_id && Emakola.Orders.PayLinkClaim.claim_for_order(payment.order_id)
        Emakola.Payments.ProtectionHolds.ensure_hold(payment)
        Emakola.Orders.SusuChunks.confirm_chunk(payment)
        Emakola.Suppliers.GroupBuys.confirm_payment(payment)
        Emakola.Suppliers.ProtectedPreorders.confirm_payment(payment)
        settle_splits(payment)
        Emakola.Suppliers.SalesTeams.settle_attributed_payment(payment)

        Emakola.Suppliers.InventoryReservations.consume_for_order(
          payment.order_id,
          payment.store_id
        )
      end

      :ok
    else
      # Permanent mismatch — already logged. Don't confirm and don't retry.
      {:error, :amount_mismatch} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Defence in depth: never confirm a charge whose gateway-reported amount or
  # currency differs from what we charged. The amount is already server-bound to
  # the order total at initiation, so a mismatch means tampering or a bug — log
  # loudly and skip rather than mark the payment paid.
  defp verify_amount(payment, data) do
    # Verify amount/currency whenever the gateway provides them. The real threat
    # is a present-but-wrong amount (tampering/bug); a genuine Paystack
    # charge.success always carries both, and webhooks are HMAC-verified, so a
    # missing field can't come from a forged request — don't reject on absence.
    amount_ok = is_nil(data["amount"]) or data["amount"] == payment.amount
    currency_ok = is_nil(data["currency"]) or to_string(data["currency"]) == payment.currency

    if amount_ok and currency_ok do
      :ok
    else
      Logger.error(
        "[paystack_webhook] charge.success amount/currency mismatch for payment=#{payment.id} " <>
          "(ref=#{payment.gateway_reference}): expected #{payment.amount} #{payment.currency}, " <>
          "got #{inspect(data["amount"])} #{inspect(data["currency"])} — not confirming"
      )

      {:error, :amount_mismatch}
    end
  end

  defp handle_charge_failed(data) do
    reference = data["reference"]

    with {:ok, payment} <- find_payment(reference),
         false <- terminal?(payment) do
      updated =
        payment
        |> Ash.Changeset.for_update(:mark_failed, %{gateway_response: data})
        |> Ash.update!(authorize?: false)

      payment
      |> payment_splits()
      |> Emakola.Payments.RefundLiability.release!()

      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "payment:#{reference}",
        {:payment_failed, reference, updated}
      )

      :ok
    else
      true -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_refund_processed(data) do
    reference = get_in(data, ["transaction", "reference"])
    event_amount = data["amount"]

    with {:ok, payment} <- find_payment(reference),
         false <- payment.status == :refunded,
         # Accumulate this refund event onto any prior partial refunds. The
         # worker is unique on [:args] for 24h, so an identical redelivery won't
         # double-count, and RefundAmountNotExceeded caps the running total.
         cumulative = (payment.refunded_amount || 0) + event_amount,
         {:ok, updated} <-
           payment
           |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: cumulative})
           |> Ash.update(authorize?: false) do
      # Reverse the split allocations so a clawback can recover each party's
      # share against future payouts.
      reverse_splits(updated)
      Emakola.Suppliers.SalesTeams.reverse_attributed_payment(updated)
      maybe_close_protection_hold(updated)

      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "payment:#{reference}",
        {:payment_refunded, reference, updated}
      )

      :ok
    else
      # Already refunded — idempotent success
      true ->
        :ok

      # Refund rejected by business rules (payment not :success, or amount
      # exceeds original). The money already moved at the gateway, so log
      # loudly — retrying won't fix a validation failure.
      {:error, %Ash.Error.Invalid{} = error} ->
        Logger.warning(
          "refund.processed rejected for payment #{reference}: #{Exception.message(error)}"
        )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # The genuine terminal success state for a refund: the cumulative amount
  # reached the full payment (`Payment.:mark_refunded` already flipped
  # `status` to `:refunded` at exactly that point — see payment.ex — so
  # this reuses that computed state rather than re-deriving "full" here). A
  # partial refund leaves `status: :success` and this is a no-op.
  # `resolution` was stashed by `RefundService.issue/5` (via
  # `ProtectionHolds.stash_refund_resolution/2`) onto
  # `payment.metadata["protection_resolution"]` — read back through a
  # `SafeAtom` allowlist since it crossed a JSON/map boundary. Never fails
  # this webhook — `ProtectionHolds.close_for_refund/2` logs and swallows.
  defp maybe_close_protection_hold(%Payment{status: :refunded} = payment) do
    resolution =
      (payment.metadata || %{})
      |> Map.get("protection_resolution")
      |> Emakola.SafeAtom.to_atom_in([:merchant_refunded, :refunded_by_staff], :merchant_refunded)

    ProtectionHolds.close_for_refund(payment, resolution)
  end

  defp maybe_close_protection_hold(_payment), do: :ok

  defp settle_splits(payment) do
    splits = payment_splits(payment)

    splits
    |> Enum.filter(&(&1.status == :pending))
    |> Enum.each(fn split ->
      split
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)
    end)

    Emakola.Payments.RefundLiability.apply_recoveries!(splits)
    Emakola.Suppliers.PartnerCredit.record_settlement(payment, splits)

    # Re-read fresh: `splits` above was fetched before the mark_settled loop,
    # so a split that just transitioned :pending -> :settled is still stale
    # in memory. Filtering the freshly-read list to status == :settled (not
    # the stale in-memory one) both matches this function's own "settled
    # split" contract literally and keeps a :reversed/:partially_reversed
    # split (e.g. an out-of-order charge.success replay after a refund
    # already landed) out of the claim path entirely, rather than relying
    # solely on the entry-side pre-guard to save it.
    payment
    |> payment_splits()
    |> Enum.filter(
      &(&1.status == :settled and &1.role == :wholesaler and not is_nil(&1.supplier_id))
    )
    |> Enum.each(&claim_supplier_ledger_entry(payment, &1))
  end

  defp reverse_splits(payment) do
    splits = payment_splits(payment)
    Emakola.Payments.RefundLiability.rollback_recoveries!(payment, splits)
    Emakola.Payments.RefundLiability.reconcile!(payment, splits)
    Emakola.Suppliers.PartnerCredit.reconcile_refund(payment, splits)

    void_fully_reversed_supplier_claims(payment)
  end

  # Claims the supplier's manual ledger entry for a settled wholesaler split so
  # the same debt is never both platform-settled and manually payable (see
  # SupplierLedgerEntry.claim_for_platform_settlement). A gateway-rail split
  # (:gateway_share) already moved the money at charge time, so the entry is
  # claimed AND marked paid immediately — an INTENTIONAL behavior change: before
  # this, a merchant could still "mark paid" the same debt by hand. An
  # internal-rail split (:internal_hold) only claims; it's marked paid once the
  # allocation payout's transfer.success arrives (see
  # mark_supplier_ledger_entries_paid/1). A no-op when the entry is already
  # claimed or paid (idempotent replay) or when no matching entry exists.
  # Never raises into the webhook — logs and continues on any failure, same
  # discipline as ProtectionHolds.ensure_hold.
  defp claim_supplier_ledger_entry(%{order_id: nil}, _split), do: :ok

  defp claim_supplier_ledger_entry(payment, split) do
    case fulfillment_ledger_entry(payment.order_id, split.supplier_id) do
      %{status: :owed, settlement_source: :manual} = entry ->
        source =
          if split.settlement_method == :gateway_share,
            do: :split_gateway,
            else: :platform_payout

        claimed =
          entry
          |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{
            payment_split_id: split.id,
            source: source
          })
          |> Ash.update!(authorize?: false)

        if source == :split_gateway do
          claimed
          |> Ash.Changeset.for_update(:mark_platform_paid, %{})
          |> Ash.update!(authorize?: false)
        end

        :ok

      # Stranded state: claim_for_platform_settlement and mark_platform_paid
      # above are two independent Ash.update! calls, not one transaction. If
      # the process crashed between them, the entry is left :owed with
      # settlement_source already :split_gateway — the :manual pre-guard on
      # the first clause can never match it again, so a plain replay would
      # otherwise strand it forever (invisible to outstanding_balance,
      # un-voidable, and un-payable manually). Finish the mark-paid here
      # instead, matching this file's existing partial-failure recovery
      # philosophy for charge.success retries (see
      # handle_charge_success/1's idempotent post-processing comment).
      %{status: :owed, settlement_source: :split_gateway} = entry ->
        entry
        |> Ash.Changeset.for_update(:mark_platform_paid, %{})
        |> Ash.update!(authorize?: false)

        :ok

      _ ->
        :ok
    end
  rescue
    error ->
      Logger.error(
        "[paystack_webhook] supplier ledger claim failed for payment=#{payment.id} " <>
          "split=#{split.id}: #{Exception.format(:error, error, __STACKTRACE__)}"
      )

      :ok
  end

  # The allocation-payout counterpart of claim_supplier_ledger_entry/2: once
  # the internal-rail transfer for this payout actually lands, every
  # SupplierLedgerEntry claimed against one of its splits (via
  # payment_split_id) can finally move :owed -> :paid. Never raises into the
  # webhook — same log-and-continue discipline as claim_supplier_ledger_entry/2.
  defp mark_supplier_ledger_entries_paid(payout) do
    {:ok, splits} = Emakola.Payments.list_payment_splits_by_payout(payout.id, authorize?: false)

    Enum.each(splits, fn split ->
      split.id
      |> Emakola.Suppliers.list_supplier_ledger_entries_by_payment_split!(authorize?: false)
      |> Enum.filter(&(&1.status == :owed))
      |> Enum.each(fn entry ->
        entry
        |> Ash.Changeset.for_update(:mark_platform_paid, %{})
        |> Ash.update!(authorize?: false)
      end)
    end)
  rescue
    error ->
      Logger.error(
        "[paystack_webhook] supplier ledger platform-paid marking failed for " <>
          "payout=#{payout.id}: #{Exception.format(:error, error, __STACKTRACE__)}"
      )

      :ok
  end

  # Refund<->supplier coupling (PR #372 follow-up): a wholesaler split that
  # RefundLiability.reconcile!/2 just drove to :reversed (fully refunded) can
  # no longer be settled by an allocation payout that will never carry this
  # money. If its ledger entry was claimed-unpaid (:platform_payout, :owed) —
  # a claim awaiting a payout that no longer applies — void it rather than
  # leave a debt the platform can neither pay nor collect. A :split_gateway
  # entry is already :paid by claim_supplier_ledger_entry/2 by the time any
  # refund can land, so it never matches here. The folded-passthrough/manual
  # case is explicitly out of scope — passthrough is settlement-time only.
  # Never raises into the webhook — same log-and-continue discipline as
  # claim_supplier_ledger_entry/2.
  defp void_fully_reversed_supplier_claims(%{order_id: nil}), do: :ok

  defp void_fully_reversed_supplier_claims(payment) do
    payment
    |> payment_splits()
    |> Enum.filter(
      &(&1.role == :wholesaler and not is_nil(&1.supplier_id) and &1.status == :reversed)
    )
    |> Enum.each(fn split ->
      case fulfillment_ledger_entry(payment.order_id, split.supplier_id) do
        %{status: :owed, settlement_source: :platform_payout} = entry ->
          entry
          |> Ash.Changeset.for_update(:void, %{})
          |> Ash.update!(authorize?: false)

        _ ->
          :ok
      end
    end)
  rescue
    error ->
      Logger.error(
        "[paystack_webhook] supplier ledger void failed for payment=#{payment.id}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )

      :ok
  end

  defp fulfillment_ledger_entry(order_id, supplier_id) do
    order_id
    |> Emakola.Orders.list_fulfillments_by_order!(authorize?: false)
    |> Enum.find(&(&1.supplier_id == supplier_id))
    |> case do
      nil ->
        nil

      fulfillment ->
        fulfillment.id
        |> Emakola.Suppliers.list_supplier_ledger_entries_by_fulfillment!(authorize?: false)
        |> List.first()
    end
  end

  # Reconciles the split ledger against a paid-out settlement batch. Membership
  # is never guessed: the documented Settlement API lists exactly which charges
  # were in the batch, and only THEIR splits get stamped — and only the splits
  # routed to this settlement's destination (the subaccount for a subaccount
  # settlement; the nil-subaccount platform rows for a main-account one).
  # References per lookup batch. A settlement is a day's payouts; without
  # batching, reconciliation cost two queries PER TRANSACTION — a 10k-charge
  # settlement meant ~20k sequential queries hogging a :webhooks queue slot.
  # Batched it is two queries per 500 references.
  @stamp_batch_size 500

  defp handle_settlement(%{"id" => settlement_id} = data) when not is_nil(settlement_id) do
    destination = get_in(data, ["subaccount", "subaccount_code"])

    case Emakola.Payments.Gateways.Paystack.settlement_transactions(settlement_id) do
      {:ok, transactions} ->
        transactions
        |> Enum.map(& &1.reference)
        |> Enum.reject(&is_nil/1)
        |> Enum.chunk_every(@stamp_batch_size)
        |> Enum.each(&stamp_settled_splits(&1, to_string(settlement_id), destination))

        :ok

      # Transient API failure — let Oban retry; insert-time uniqueness and the
      # is-nil-reference filter make the retry safe.
      {:error, reason} ->
        {:error, {:settlement_reconciliation_failed, reason}}
    end
  end

  defp handle_settlement(data) do
    Logger.warning("[paystack_webhook] settlement event without an id: #{inspect(data)}")
    :ok
  end

  # One payments read and one splits read per batch of references. References
  # that are not ours (another integration on the same Paystack account) simply
  # match no payment and drop out. The destination filter stays in Elixir:
  # `subaccount_code == destination` must also match nil == nil for
  # main-account settlements, which an expr pin does not express cleanly.
  defp stamp_settled_splits(references, settlement_id, destination) do
    reference_by_payment_id =
      Payment
      |> Ash.Query.filter(gateway_reference in ^references)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.id, &1.gateway_reference})

    payment_ids = Map.keys(reference_by_payment_id)

    Emakola.Payments.PaymentSplit
    |> Ash.Query.filter(payment_id in ^payment_ids and is_nil(paystack_split_reference))
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(&1.subaccount_code == destination))
    |> Enum.each(fn split ->
      stamp_split(split, settlement_id, Map.get(reference_by_payment_id, split.payment_id))
    end)
  end

  # A split still :pending when its money has demonstrably been PAID OUT means
  # we never processed the charge.success — that needs a human, not a silent
  # status jump that would skip the settle-time side effects (recoveries,
  # partner credit).
  defp stamp_split(%{status: :pending} = split, settlement_id, reference) do
    Logger.warning(
      "[paystack_webhook] settlement #{settlement_id} includes charge #{reference} " <>
        "whose split #{split.id} is still :pending — charge.success was never processed"
    )
  end

  defp stamp_split(split, settlement_id, _reference) do
    split
    |> Ash.Changeset.for_update(:record_settlement_reference, %{
      paystack_split_reference: settlement_id
    })
    |> Ash.update!(authorize?: false)
  end

  defp payment_splits(payment) do
    {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
    splits
  end

  defp find_payment(reference) do
    case Payment
         |> Ash.Query.filter(gateway_reference == ^reference)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :payment_not_found}
      {:ok, payment} -> {:ok, payment}
      {:error, reason} -> {:error, reason}
    end
  end

  defp terminal?(%{status: status}) when status in @terminal_states, do: true
  defp terminal?(_), do: false

  defp maybe_confirm_order(nil), do: :ok

  defp maybe_confirm_order(order_id) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(id == ^order_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, %{status: :pending} = order} ->
        result =
          order
          |> Ash.Changeset.for_update(:confirm, %{})
          |> Ash.update(authorize?: false)

        case result do
          {:ok, confirmed_order} ->
            try do
              Emakola.Notifications.Dispatcher.dispatch(confirmed_order, :order_confirmed)
            rescue
              _ -> :ok
            end

            {:ok, confirmed_order}

          error ->
            error
        end

      _ ->
        :ok
    end
  end
end
