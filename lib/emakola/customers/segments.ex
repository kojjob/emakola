defmodule Emakola.Customers.Segments do
  @moduledoc """
  Who a merchant is talking to. Four segments over order history, no new
  tracking: New, Bought again, Big spenders, Gone quiet. Everyone is the
  fifth, for the campaign page.

  Big spenders is the top fifth of paying customers by paid money, and only
  once five people have bought; under that, a "top fifth" is one person and
  says nothing.
  """

  require Ash.Query

  alias Emakola.Customers.Customer

  @segments [:everyone, :new, :bought_again, :big_spenders, :gone_quiet]
  @new_days 30
  @quiet_days 60
  @min_buyers_for_big 5

  @type segment :: :everyone | :new | :bought_again | :big_spenders | :gone_quiet

  @spec all() :: [segment()]
  def all, do: @segments

  @spec label(segment()) :: String.t()
  def label(:everyone), do: "Everyone"
  def label(:new), do: "New"
  def label(:bought_again), do: "Bought again"
  def label(:big_spenders), do: "Big spenders"
  def label(:gone_quiet), do: "Gone quiet"

  @doc "Customers of `store_id` in `segment`, as a query the caller can count, load, or page."
  @spec query(binary(), segment()) :: Ash.Query.t()
  def query(store_id, :everyone) do
    Customer |> Ash.Query.filter(store_id == ^store_id)
  end

  def query(store_id, :new) do
    since = days_ago(@new_days)
    Customer |> Ash.Query.filter(store_id == ^store_id and first_paid_order_at >= ^since)
  end

  def query(store_id, :bought_again) do
    Customer |> Ash.Query.filter(store_id == ^store_id and paid_order_count >= 2)
  end

  def query(store_id, :gone_quiet) do
    cutoff = days_ago(@quiet_days)

    Customer
    |> Ash.Query.filter(
      store_id == ^store_id and paid_order_count >= 1 and last_order_at < ^cutoff
    )
  end

  def query(store_id, :big_spenders) do
    case big_spender_floor(store_id) do
      nil -> Customer |> Ash.Query.filter(store_id == ^store_id and false)
      floor -> Customer |> Ash.Query.filter(store_id == ^store_id and paid_total >= ^floor)
    end
  end

  @spec counts(binary()) :: %{segment() => non_neg_integer()}
  def counts(store_id) do
    Map.new(@segments, fn segment ->
      {segment, store_id |> query(segment) |> Ash.count!(authorize?: false)}
    end)
  end

  # The paid_total at the 80th percentile among customers who have paid.
  # Loads every paying customer's total into memory to sort it — fine at the
  # scale a single store's paying customers reach; revisit if a store's paying
  # customer count grows large enough for this to matter.
  defp big_spender_floor(store_id) do
    totals =
      Customer
      |> Ash.Query.filter(store_id == ^store_id and paid_order_count >= 1)
      |> Ash.Query.load(:paid_total)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&(&1.paid_total || 0))
      |> Enum.sort(:desc)

    if length(totals) < @min_buyers_for_big do
      nil
    else
      keep = max(1, div(length(totals), 5))
      Enum.at(totals, keep - 1)
    end
  end

  defp days_ago(days), do: DateTime.add(DateTime.utc_now(), -days * 86_400, :second)
end
