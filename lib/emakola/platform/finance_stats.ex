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

  `Payment` and `PaymentSplit` are `global?: true`, so these aggregate across all
  stores with `authorize?: false` (called only from the gated platform admin).
  """
  require Ash.Query

  alias Emakola.Payments.Payment
  alias Emakola.Payments.PaymentSplit

  @doc "Total platform fees collected (minor units)."
  def total_platform_fees do
    PaymentSplit
    |> Ash.Query.filter(role == :platform)
    |> sum_amount()
  end

  @doc "Total successful payments the platform still owes merchants (un-split, minor units)."
  def total_outstanding_payouts do
    Payment
    |> Ash.Query.filter(status == :success and split_mode == :none)
    |> sum_amount()
  end

  @doc """
  Per-store finance rows — one per store with fees or an outstanding balance,
  sorted by outstanding owed (descending — the manual-payout worklist).

  Each row: `%{store, fees_collected, outstanding_owed, payouts_ready?}`.
  """
  def per_store_finance do
    fees_by_store = sum_amount_by_store(platform_fee_splits())
    owed_by_store = sum_amount_by_store(unsplit_success_payments())
    ready = verified_payout_store_ids()

    store_ids = Enum.uniq(Map.keys(fees_by_store) ++ Map.keys(owed_by_store))
    stores = load_stores(store_ids)

    store_ids
    |> Enum.map(fn id ->
      %{
        store: Map.get(stores, id),
        fees_collected: Map.get(fees_by_store, id, 0),
        outstanding_owed: Map.get(owed_by_store, id, 0),
        payouts_ready?: MapSet.member?(ready, id)
      }
    end)
    |> Enum.filter(& &1.store)
    |> Enum.sort_by(& &1.outstanding_owed, :desc)
  end

  # ── helpers ────────────────────────────────────────────────────────

  defp sum_amount(query) do
    case Ash.sum(query, :amount, authorize?: false) do
      {:ok, total} when is_integer(total) -> total
      _ -> 0
    end
  end

  defp platform_fee_splits do
    PaymentSplit
    |> Ash.Query.filter(role == :platform)
    |> Ash.read!(authorize?: false)
  end

  defp unsplit_success_payments do
    Payment
    |> Ash.Query.filter(status == :success and split_mode == :none)
    |> Ash.read!(authorize?: false)
  end

  defp sum_amount_by_store(rows) do
    Enum.reduce(rows, %{}, fn row, acc ->
      Map.update(acc, row.store_id, row.amount, &(&1 + row.amount))
    end)
  end

  defp verified_payout_store_ids do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Query.filter(verification_status == :verified and not is_nil(subaccount_code))
    |> Ash.read!(authorize?: false)
    |> MapSet.new(& &1.store_id)
  end

  defp load_stores([]), do: %{}

  defp load_stores(ids) do
    Emakola.Stores.Store
    |> Ash.Query.filter(id in ^ids)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, &1})
  end
end
