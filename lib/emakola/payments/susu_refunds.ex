defmodule Emakola.Payments.SusuRefunds do
  @moduledoc """
  Order-less refunds for susu plan contributions (TC-3 Task 6).

  `Emakola.Payments.RefundService` cannot be reused here: it is built
  around a `Return` row (a returns request against a captured ORDER), and
  susu contributions are refunded pre-completion — expiry/cancel happen
  before any order exists (`Emakola.Orders.SusuCompletion` is what turns a
  plan into an order, and only a `:completed` plan gets one) — so there is
  no `Return` to approve. This module refunds every counted contribution
  Payment directly.

  ## Claim discipline (mirrors `RefundService`)

  `RefundService.claim/1` (`refund_service.ex:124-134`) takes a
  `FOR UPDATE` lock on the Return row and re-reads its status fresh from
  the database — never a caller-held struct — so two concurrent callers
  (a sweep re-run, a merchant double-click) can't both refund the same
  charge. `claim_payment/1` below does the exact same thing at the
  PAYMENT row: lock `FOR UPDATE`, re-read `metadata["susu_refund_claimed"]`
  fresh, and only stamp it when it isn't already `true`.

  `RefundService.request_refund/3` (`refund_service.ex:223-235`) treats
  every gateway failure the same way, whether the underlying cause was a
  definite provider rejection or a network failure — see
  `Emakola.Payments.Gateways.Paystack.process_refund/2`, which has two
  DISTINCT clauses producing these: `{:ok, %{"status" => false, ...}} ->
  {:error, {:paystack_error, message}}` for a provider rejection, and
  `{:error, reason} -> {:error, {:gateway_error, reason}}` for a
  transport-level failure. Different shapes, but both are `{:error, _}`
  by the time they reach the caller, and `RefundService` treats them
  identically regardless of which one fired. `RefundService.issue/5`
  (`refund_service.ex:106-118`)
  wraps the whole claim+approve+refund sequence in ONE `Repo.transaction`,
  so ANY `{:error, _}` from that `with` chain rolls EVERYTHING back
  (`Repo.rollback/1`) — the Return reverts to `:requested`, safe to retry,
  because nothing was left ambiguous. That safety, in turn, rests on
  `Emakola.Payments.PaystackClient.create_refund/1` (`paystack_client.ex:36-47`)
  being deliberately "bounded and non-retrying" (`receive_timeout: 10_000,
  retry: false`) — the exact comment there: "a retried refund POST whose
  first response was merely lost is a double refund". Because the HTTP
  layer itself never silently re-sends the POST, by the time
  `process_refund/2` returns there is no request still in flight — an
  `{:error, _}` means the gateway definitively did not accept the refund
  (a rejection, or a bounded timeout with nothing sent back), never "maybe
  it landed, maybe it didn't".

  This module mirrors that exact split — claim, then call the gateway,
  release on a definite error, keep on acceptance — just without one
  enclosing transaction: looping over N contributions can't hold N network
  calls inside a single DB transaction (the same reasoning
  `SusuChunks.confirm_chunk/1`'s moduledoc gives for running stock
  reservation outside its own lock). So the claim commits on its own
  first, then the gateway is called outside any lock:

    * `{:ok, _}` — the claim stays. The refund was accepted; whether it
      actually lands is confirmed later by the `refund.processed` webhook
      (`payment.:refunded` — this module never writes that state itself,
      same "only initiates" discipline `RefundService` documents).
      Retrying an accepted refund would double-refund, so nothing here
      ever re-asks the gateway for an already-accepted request.
    * `{:error, _}` — the claim is released. The gateway never accepted
      the refund, so it's both safe and necessary to retry on the next
      sweep or cancel/expiry call.

  A payment claimed and then never reaching either branch (the process
  crashes between the claim committing and the gateway call returning) is
  left claimed — the same "ambiguous outcomes get no automatic retry"
  posture `RefundService`'s one-big-transaction design achieves by a
  different mechanism (a crash there rolls the claim back too, but ONLY
  because approve+refund share one transaction; here, deliberately, they
  don't). This is a documented, accepted risk window, not a gap silently
  introduced — the equivalent window `SusuChunks.initiate_chunk/4`'s
  moduledoc already accepts for chunk initiation.

  ## Hubtel

  `Gateways.Hubtel.process_refund/2` always returns `{:error, :not_supported}`
  — Hubtel has no refund API; a merchant has to issue it by hand in
  Hubtel's own dashboard. Today `SusuChunks.do_initiate/2` hardcodes
  `gateway: :paystack` on every chunk Payment row regardless of which
  gateway module actually charged it (the same hardcoding
  `Emakola.Suppliers.GroupBuys`/`ProtectedPreorders` already have at their
  own payment-create call sites), so no susu contribution is stamped
  `gateway: :hubtel` in practice today — but the Payment schema allows it,
  and this module routes by `payment.gateway` exactly as
  `RefundService.gateway_for/1` does, so a Hubtel-charged contribution (a
  future fix to that hardcoding, or a payment stamped by hand) is still
  handled instead of crashing the sweep: `:not_supported` releases the
  claim (same as any other `{:error, _}` — a merchant who refunded it by
  hand in Hubtel's dashboard isn't blocked from that being the end of it)
  and flags the payment for manual attention with a dedup'd note, mirroring
  `SusuChunks.flag_for_refund/2`'s exact guard shape.
  """

  require Ash.Query
  require Logger

  alias Emakola.Orders.SusuPlan
  alias Emakola.Payments.Gateways
  alias Emakola.Payments.Payment
  alias Emakola.Repo

  @manual_refund_note "⚠️ Susu refund could not be initiated automatically (gateway does not support refunds) — refund this payment manually."

  @doc """
  Initiates a gateway refund for every contribution counted toward `plan`
  (`metadata["susu_counted"] == true` — the same definition
  `SusuCompletion.load_contributions/1` uses) that isn't already claimed
  or refunded. Safe to call more than once for the same plan: an
  already-claimed or already-`:refunded` payment is skipped, and a
  payment whose prior initiation failed is retried.

  Always returns `:ok` — failures are logged (and, for a gateway that
  doesn't support refunds at all, flagged on the payment) rather than
  raised, so a caller sweeping many plans keeps moving.
  """
  def refund_all_contributions(%SusuPlan{id: plan_id}) do
    plan_id
    |> counted_contributions()
    |> Enum.each(&guarded_refund_contribution/1)

    :ok
  end

  defp counted_contributions(plan_id) do
    Payment
    |> Ash.Query.filter(susu_plan_id == ^plan_id)
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&counted?/1)
  end

  defp counted?(%Payment{metadata: metadata}),
    do: Map.get(metadata || %{}, "susu_counted") == true

  # One contribution's unexpected failure (a raised exception — a Mox
  # verification error, a transient DB error — as opposed to an ordinary
  # gateway {:error, _}) must not stop the rest of the plan's
  # contributions from being refunded. Same discipline `SusuChunks`'s
  # `guarded_*` helpers use.
  defp guarded_refund_contribution(payment) do
    refund_contribution(payment)
  rescue
    error ->
      Logger.error(
        "[susu_refunds] refund failed for payment=#{payment.id}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )
  end

  defp refund_contribution(payment) do
    {:ok, result} = claim_payment(payment.id)

    case result do
      {:claimed, claimed} -> initiate_gateway_refund(claimed)
      _already_settled -> :ok
    end
  end

  # FOR UPDATE claim on the payment row, re-read fresh from the DB —
  # mirrors `RefundService.claim/1`'s exact discipline
  # (refund_service.ex:124-134): lock, re-read, decide from the row itself
  # rather than a caller-supplied struct. Its own short transaction (not
  # shared with the gateway call) — see moduledoc.
  defp claim_payment(payment_id) do
    Repo.transaction(fn ->
      case locked_payment(payment_id) do
        nil ->
          :not_found

        %Payment{status: :refunded} ->
          :already_refunded

        %Payment{metadata: metadata} = fresh ->
          if claimed?(metadata) do
            :already_claimed
          else
            {:claimed, stamp_claim!(fresh)}
          end
      end
    end)
  end

  defp claimed?(metadata), do: Map.get(metadata || %{}, "susu_refund_claimed") == true

  defp locked_payment(payment_id) do
    Payment
    |> Ash.Query.filter(id == ^payment_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp stamp_claim!(payment) do
    payment
    |> Ash.Changeset.for_update(:update, %{
      metadata: Map.put(payment.metadata || %{}, "susu_refund_claimed", true)
    })
    |> Ash.update!(authorize?: false)
  end

  # `{:ok, _}` — kept claimed (accepted, ambiguous until the
  # `refund.processed` webhook confirms it — see moduledoc).
  # `{:error, _}` — released (never accepted; safe and necessary to
  # retry — mirrors `RefundService.request_refund/3`'s uniform treatment
  # of every gateway error, refund_service.ex:223-235).
  defp initiate_gateway_refund(payment) do
    case gateway_for(payment).process_refund(payment.gateway_reference, payment.amount) do
      {:ok, _response} ->
        :ok

      {:error, :not_supported} ->
        payment
        |> release_claim!()
        |> flag_for_manual_attention!()

        Logger.error(
          "[susu_refunds] gateway does not support refunds for payment=#{payment.id} — needs manual attention"
        )

        :ok

      {:error, reason} ->
        release_claim!(payment)

        Logger.error(
          "[susu_refunds] refund initiation failed for payment=#{payment.id}: " <>
            inspect(reason)
        )

        :ok
    end
  end

  defp release_claim!(payment) do
    payment
    |> Ash.Changeset.for_update(:update, %{
      metadata: Map.put(payment.metadata || %{}, "susu_refund_claimed", false)
    })
    |> Ash.update!(authorize?: false)
  end

  # Mirrors `SusuChunks.flag_for_refund/2`'s exact dedup-guard shape,
  # reusing the same `metadata["refund_note"]` key so a later admin
  # surface has one place to look for any susu payment needing manual
  # refund attention, whichever module flagged it.
  defp flag_for_manual_attention!(payment) do
    note = Map.get(payment.metadata || %{}, "refund_note", "")

    if String.contains?(note, @manual_refund_note) do
      payment
    else
      updated_note = String.trim("#{note}\n#{@manual_refund_note}")

      payment
      |> Ash.Changeset.for_update(:update, %{
        metadata: Map.put(payment.metadata || %{}, "refund_note", updated_note)
      })
      |> Ash.update!(authorize?: false)
    end
  end

  # Mirrors `RefundService.gateway_for/1` exactly (refund_service.ex:248-252)
  # — the refund goes back through the gateway that took the money, keyed
  # off `payment.gateway` (never a caller-supplied override — see
  # moduledoc's Hubtel section for why that field can be trusted here).
  defp gateway_for(%Payment{gateway: :hubtel}), do: Gateways.Hubtel

  defp gateway_for(_payment),
    do: Application.get_env(:emakola, :payment_gateway, Gateways.Paystack)
end
