defmodule Emakola.Orders.SusuCompletion do
  @moduledoc """
  Turns a `:completed` susu plan (TC-3) into a real, confirmed order —
  `Emakola.Payments.Workers.SusuCompletionWorker`'s real work.

  `complete/1` runs in one transaction, under a `FOR UPDATE` lock on the
  plan row:

    1. Idempotency check — an order already exists for this plan (a prior
       run committed, or the worker fired twice) short-circuits, returning
       the existing order untouched. No `orders.susu_plan_id` uniqueness
       constraint exists at the DB level, so this lock+check is the only
       thing preventing a double-create.
    2. Otherwise, creates the order (`CheckoutService.create_susu_order!/1`
       — catalog or custom line, plan-derived pricing, merchant-owned
       fulfillment, shipping address from the plan's stored delivery
       address).
    3. Loads every contribution actually counted toward the plan
       (`metadata["susu_counted"] == true` — a payment can be `:success`
       at the gateway yet never counted, e.g. flagged for refund by
       `SusuChunks.confirm_chunk/1`) and stamps `order_id` onto each via
       `Payment.:attach_order`.
    4. Apportions the plan's platform fee across those contributions
       (`apportion_fees/2`) and, per contribution, either releases its
       `"susu_plan"` payout hold (ordinary payout path) or converts it into
       a buyer-protection hold (store has protection enabled — susu has no
       pay link, so `Protection.applies?(store, nil)` is the store-level
       check).
    5. Confirms the order (`Order.:confirm`) so fulfillment dispatch and
       the `order_confirmed` notification fire exactly like any other paid
       order. `Changes.DecrementStock` no-ops for it (`susu_plan_id` set —
       stock was already decremented once, at plan activation, by Task 4's
       `SusuStock.reserve/1`).

  `order_placed` is dispatched separately, OUTSIDE the transaction and only
  on a genuine (non-idempotent-replay) completion — the same "outside the
  transaction, never on the no-op branch" discipline `CheckoutService`
  itself uses for the identical notification.

  ## Fee apportionment

  `total_fee = PlatformFee.calculate(plan.total_amount, plan.fee_rate_bps).fee`
  is the platform's cut of the WHOLE plan. Each contribution's fee is
  independently floored the same way (`PlatformFee.calculate(amount_i,
  fee_rate_bps).fee`); flooring drops a fractional pesewa here and there,
  so the sum of those per-contribution fees can fall short of `total_fee`
  by a few pesewas. The shortfall is added to the LAST contribution's fee
  (chronologically, by `inserted_at` — the contribution that actually
  completed the plan). This is a runtime-checked invariant, not just an
  assumption: `Σfee_i == total_fee` and every `payable_i = amount_i - fee_i
  >= 0` are asserted before anything is written, and a violation raises
  (loudly, not silently) so Oban retries rather than the worker recording
  success over broken money math.
  """

  import Ecto.Query, only: [from: 2]
  require Ash.Query
  require Logger

  alias Emakola.Notifications.Dispatcher
  alias Emakola.Orders.CheckoutService
  alias Emakola.Orders.Order
  alias Emakola.Orders.SusuPlan
  alias Emakola.Payments.Payment
  alias Emakola.Payments.PlatformFee
  alias Emakola.Payments.Protection
  alias Emakola.Repo

  # Builds the FOR-UPDATE row lookup used by `complete/1`. Exposed (not
  # private) so `SusuCompletionTest` can pass it to `Ecto.Adapters.SQL.to_sql/3`
  # and assert the lock clause is present — mirrors `SusuChunks.locked_plan_query/1`
  # / `ProtectionRelease.locked_row_query/1`.
  @doc false
  def locked_plan_query(plan_id) do
    from(p in "susu_plans",
      where: p.id == type(^plan_id, :binary_id),
      lock: "FOR UPDATE",
      select: %{id: type(p.id, :binary_id)}
    )
  end

  @doc """
  Idempotently completes susu plan `plan_id`: creates its order (if one
  doesn't already exist), attaches every counted contribution, apportions
  the platform fee, composes buyer protection, and confirms the order.

  Returns `{:ok, order}` whether this call did the work or found it already
  done. Raises on a genuine invariant violation (fee apportionment gone
  wrong) — the worker calling this does NOT rescue, by design: Oban should
  retry, and retrying is safe because every step here is idempotent.
  """
  def complete(plan_id) do
    {kind, order} =
      Repo.transaction(fn ->
        _locked = Repo.one(locked_plan_query(plan_id))

        case existing_order(plan_id) do
          %Order{} = order -> {:existing, order}
          nil -> {:new, complete_fresh!(plan_id)}
        end
      end)
      |> unwrap!()

    if kind == :new, do: dispatch_order_placed(order)

    {:ok, order}
  end

  defp unwrap!({:ok, result}), do: result

  defp existing_order(plan_id) do
    Order
    |> Ash.Query.filter(susu_plan_id == ^plan_id)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp complete_fresh!(plan_id) do
    plan = Ash.get!(SusuPlan, plan_id, authorize?: false)
    store = Ash.get!(Emakola.Stores.Store, plan.store_id, authorize?: false)

    order = CheckoutService.create_susu_order!(plan)

    plan.id
    |> load_contributions()
    |> apportion_fees(plan)
    |> Enum.each(fn %{payment: payment, fee: fee, payable: payable} ->
      payment
      |> attach_order!(order.id)
      |> settle_contribution!(store, order, fee, payable)
    end)

    # `:confirm`'s `DecrementStock` change runs `after_transaction` — Ash
    # warns by default when an `after_transaction` hook fires inside an
    # ambient transaction (ours), since that hook usually assumes it's
    # running after the REAL commit. Safe to silence here specifically:
    # `DecrementStock` no-ops unconditionally for a susu order
    # (`susu_plan_id` set — see its moduledoc), regardless of when the hook
    # actually fires.
    order
    |> Ash.Changeset.for_update(:confirm, %{})
    |> Ash.Changeset.set_context(%{warn_on_transaction_hooks?: false})
    |> Ash.update!(authorize?: false)
  end

  # Only contributions actually counted toward the plan — a payment can be
  # `:success` at the gateway yet never counted (flagged for refund instead,
  # e.g. it would have overshot the total — see `SusuChunks.confirm_chunk/1`).
  # Sorted oldest-first so "the last contribution absorbs the remainder"
  # (see moduledoc) is deterministic: the contribution that actually
  # completed the plan.
  defp load_contributions(plan_id) do
    Payment
    |> Ash.Query.filter(susu_plan_id == ^plan_id)
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&counted?/1)
    |> Enum.sort_by(& &1.inserted_at, DateTime)
  end

  defp counted?(%Payment{metadata: metadata}),
    do: Map.get(metadata || %{}, "susu_counted") == true

  defp apportion_fees(contributions, plan) do
    total_fee = PlatformFee.calculate(plan.total_amount, plan.fee_rate_bps).fee

    contributions
    |> Enum.map(fn payment ->
      %{payment: payment, fee: PlatformFee.calculate(payment.amount, plan.fee_rate_bps).fee}
    end)
    |> absorb_remainder(total_fee)
    |> Enum.map(fn %{payment: payment, fee: fee} ->
      %{payment: payment, fee: fee, payable: payment.amount - fee}
    end)
    |> assert_invariants!(total_fee, plan)
  end

  defp absorb_remainder([], _total_fee), do: []

  defp absorb_remainder(provisional, total_fee) do
    remainder = total_fee - Enum.sum(Enum.map(provisional, & &1.fee))
    List.update_at(provisional, -1, fn last -> %{last | fee: last.fee + remainder} end)
  end

  defp assert_invariants!(apportioned, total_fee, plan) do
    sum_fees = apportioned |> Enum.map(& &1.fee) |> Enum.sum()

    unless sum_fees == total_fee do
      raise "susu completion fee apportionment mismatch for plan=#{plan.id}: " <>
              "sum of per-contribution fees (#{sum_fees}) != platform fee on the plan total (#{total_fee})"
    end

    Enum.each(apportioned, fn %{payment: payment, payable: payable} ->
      if payable < 0 do
        raise "susu completion produced a negative payable (#{payable}) for " <>
                "payment=#{payment.id}, plan=#{plan.id}"
      end
    end)

    apportioned
  end

  defp attach_order!(payment, order_id) do
    payment
    |> Ash.Changeset.for_update(:attach_order, %{order_id: order_id})
    |> Ash.update!(authorize?: false)
  end

  # Store-level protection check — susu orders have no pay link, so
  # `Protection.applies?/2` reads the store's `buyer_protection_enabled`
  # setting (the `nil` second argument is its "no pay link" clause).
  defp settle_contribution!(payment, store, order, fee, payable) do
    if Protection.applies?(store, nil) do
      Emakola.Payments.create_protection_hold!(
        %{
          store_id: payment.store_id,
          payment_id: payment.id,
          order_id: order.id,
          amount: payment.amount,
          fee: fee,
          net: payable
        },
        tenant: payment.store_id,
        authorize?: false
      )

      payment
      |> Ash.Changeset.for_update(:mark_buyer_protection_hold, %{})
      |> Ash.update!(authorize?: false)
    else
      payment
      |> Ash.Changeset.for_update(:release_payout_hold, %{payable_amount: payable})
      |> Ash.update!(authorize?: false)
    end
  end

  defp dispatch_order_placed(order) do
    case Dispatcher.dispatch(order, :order_placed) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[susu_completion] order_placed dispatch failed: #{inspect(reason)}",
          order_id: order.id
        )
    end
  end
end
