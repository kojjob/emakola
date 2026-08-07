defmodule Emakola.Platform.FinanceStats do
  @moduledoc """
  Platform revenue aggregates for the finance-oversight page (`/platform/finance`).

  Two headline numbers, both in integer minor units (display formats in the
  presentation layer):

    * **Platform fees collected** — `PaymentSplit` rows with `role: :platform`
      (the 2% normal-order fee and the 10% dropship margin the platform keeps).
    * **Outstanding merchant payouts** — successful **un-split** (`split_mode:
      :none`) payments. With split-at-source the merchant is paid directly by the
      gateway, so the only money the platform holds and owes is from orders that
      settled to the main account because the store had no verified subaccount.
      Plus payable internal-rail `PaymentSplit` allocations (`settlement_method:
      :internal_hold`) owed to their recipient stores — dropship money the
      platform holds on the ledger rather than at the gateway.

  `Payment` and `PaymentSplit` are `global?: true`, so these aggregate across all
  stores with `authorize?: false` (called only from the gated platform admin).
  """
  require Ash.Query

  alias Emakola.Payments.Payment
  alias Emakola.Payments.PaymentSplit

  @doc """
  Total platform fees collected (minor units).

  Only confirmed money counts: a `:pending` split is a charge the gateway has
  not confirmed, and a reversed amount was clawed back by a refund. This page
  used to sum every `:platform` row regardless of status, overstating revenue.
  """
  def total_platform_fees do
    platform_fees_total()
  end

  @doc """
  Total successful payments the platform still owes merchants (minor units):
  un-split payments, plus payable internal-rail splits owed to their
  recipient stores.
  """
  def total_outstanding_payouts do
    legacy = unsplit_success_payments() |> Enum.map(&payable_amount/1) |> Enum.sum()
    internal = payable_internal_splits() |> Enum.map(&payable_net/1) |> Enum.sum()
    legacy + internal
  end

  @doc """
  Per-store finance rows — one per store with fees or an outstanding balance,
  sorted by outstanding owed (descending — the manual-payout worklist).

  Each row: `%{store, fees_collected, outstanding_owed, legacy_owed,
  internal_owed, payouts_ready?}`. `legacy_owed` (un-split payments basis) and
  `internal_owed` (ledger/allocations basis) are kept separate — not just
  summed into `outstanding_owed` — so a caller can show the dual-basis
  breakdown before approving a payout.
  """
  def per_store_finance do
    fees_by_store = platform_fees_by_store()
    legacy_by_store = sum_by_store(unsplit_success_payments(), &payable_amount/1)

    internal_by_store =
      sum_by_store_key(payable_internal_splits(), & &1.recipient_store_id, &payable_net/1)

    store_ids =
      Enum.uniq(
        Map.keys(fees_by_store) ++ Map.keys(legacy_by_store) ++ Map.keys(internal_by_store)
      )

    stores = load_stores(store_ids)

    store_ids
    |> Enum.map(fn id ->
      legacy = Map.get(legacy_by_store, id, 0)
      internal = Map.get(internal_by_store, id, 0)

      %{
        store: Map.get(stores, id),
        fees_collected: Map.get(fees_by_store, id, 0),
        outstanding_owed: legacy + internal,
        legacy_owed: legacy,
        internal_owed: internal,
        payouts_ready?: Emakola.Payments.PayoutService.momo_destination?(id)
      }
    end)
    |> Enum.filter(& &1.store)
    |> Enum.sort_by(& &1.outstanding_owed, :desc)
  end

  @doc """
  Splits stamped as unreclaimable releases (`PaymentSplit.needs_remediation` —
  `release_from_payout` stamped `recovery_breakdown["unreclaimable_release"]`):
  audit trail of fully-reversed failed-payout claims with their recipient store
  resolved, newest-flagged first. These rows carry no outstanding debt.
  See `PaymentSplit.needs_remediation`.

  Each row: `%{split, store}`.
  """
  def remediation_splits do
    {:ok, splits} = Emakola.Payments.list_remediation_splits(authorize?: false)
    stores = splits |> Enum.map(& &1.recipient_store_id) |> Enum.uniq() |> load_stores()

    Enum.map(splits, &%{split: &1, store: Map.get(stores, &1.recipient_store_id)})
  end

  @doc """
  Confirmed platform fees (minor units) per day, oldest first, gaps filled —
  the finance hero's trend series. Same fee definition as
  `total_platform_fees/0` (non-pending platform splits, reversals netted),
  bucketed in Elixir like `Stats.gmv_by_day/1`.
  """
  def platform_fees_by_day(days \\ 30) do
    today = Date.utc_today()
    start_date = Date.add(today, -(days - 1))

    fees_by_date =
      platform_fee_splits()
      |> Enum.group_by(&DateTime.to_date(&1.inserted_at))

    buckets =
      Enum.map(Date.range(start_date, today), fn date ->
        daily_total = fees_by_date |> Map.get(date, []) |> Enum.map(&net_amount/1) |> Enum.sum()
        {Calendar.strftime(date, "%b %d"), daily_total}
      end)

    %{labels: Enum.map(buckets, &elem(&1, 0)), values: Enum.map(buckets, &elem(&1, 1))}
  end

  # ── helpers ────────────────────────────────────────────────────────

  # Confirmed fee rows only — never :pending. Reversals are netted in the
  # SUM itself (a fully :reversed row contributes zero). This filter is
  # local to this module (not a shared named read action like
  # :outstanding_for_payout below), so computing it directly in SQL carries
  # no duplication risk — it was already the single definition, just moved
  # from an Elixir Enum.sum over every matching row to a DB-side sum.
  # `amount`/`reversed_amount` are `bigint` columns — Postgres's SUM(bigint)
  # returns `numeric` (overflow-safe), which Postgrex decodes as `Decimal`.
  # `type(..., :integer)` casts the aggregate back to a plain integer; money
  # here is always minor-unit integers, never floats or decimals.
  defp platform_fees_total do
    import Ecto.Query

    from(s in PaymentSplit,
      where: s.role == :platform and s.status != :pending,
      select: coalesce(type(sum(s.amount - s.reversed_amount), :integer), 0)
    )
    |> Emakola.Repo.one()
  end

  defp platform_fees_by_store do
    import Ecto.Query

    from(s in PaymentSplit,
      where: s.role == :platform and s.status != :pending,
      group_by: s.store_id,
      select: {s.store_id, type(sum(s.amount - s.reversed_amount), :integer)}
    )
    |> Emakola.Repo.all()
    |> Map.new()
  end

  # What PayoutService actually pays for a payment — the released
  # buyer-protection net when present, otherwise the gross amount. Kept in
  # one place so this page can never overstate what a payout would actually
  # pay (see PayoutService.prepare_payout/1's identical expression).
  defp payable_amount(payment), do: payment.payable_amount || payment.amount

  # "Outstanding" is defined once, on the resource — see
  # Payment.outstanding_for_payout. PayoutService pays out what this reports.
  defp unsplit_success_payments do
    Payment
    |> Ash.Query.for_read(:outstanding_for_payout, %{store_id: nil})
    |> Ash.read!(authorize?: false)
  end

  # Payable internal-rail splits (allocation-basis money the platform holds
  # for a recipient store) — the split-level sibling of unsplit_success_payments.
  # See PaymentSplit.payable_internal, the single authority for this population.
  defp payable_internal_splits do
    {:ok, splits} = Emakola.Payments.list_payable_internal_splits(nil, authorize?: false)
    splits
  end

  # Display sums are GROSS payable; the payout engine additionally nets
  # outstanding refund liability at payout time (P2a), so an indebted
  # recipient's actual transfer can be smaller. Liability-aware display is the
  # P2b/UI pass. This delegates to PaymentSplit.frozen_paid_amount/1, the
  # single formula authority also called by mark_paid_out and
  # PayoutService.prepare_internal_payout/1.
  defp payable_net(split), do: PaymentSplit.frozen_paid_amount(split)

  defp sum_by_store(rows, value_fun) do
    Enum.reduce(rows, %{}, fn row, acc ->
      Map.update(acc, row.store_id, value_fun.(row), &(&1 + value_fun.(row)))
    end)
  end

  defp sum_by_store_key(rows, key_fun, value_fun) do
    Enum.reduce(rows, %{}, fn row, acc ->
      Map.update(acc, key_fun.(row), value_fun.(row), &(&1 + value_fun.(row)))
    end)
  end

  defp load_stores([]), do: %{}

  defp load_stores(ids) do
    Emakola.Stores.Store
    |> Ash.Query.filter(id in ^ids)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, &1})
  end
end
