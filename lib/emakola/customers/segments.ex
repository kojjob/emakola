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
  require Logger

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

    # last_paid_order_at, not last_order_at — CheckoutService touches
    # last_order_at on every checkout, including unpaid ones, so a recent
    # abandoned cart would otherwise hide a customer who hasn't PAID in ages.
    Customer
    |> Ash.Query.filter(
      store_id == ^store_id and paid_order_count >= 1 and last_paid_order_at < ^cutoff
    )
  end

  def query(store_id, :big_spenders) do
    case big_spender_floor(store_id) do
      nil -> Customer |> Ash.Query.filter(store_id == ^store_id and false)
      floor -> Customer |> Ash.Query.filter(store_id == ^store_id and paid_total >= ^floor)
    end
  end

  # A stale value (an old campaign's audience, a hand-edited row) is not one
  # of the five known segments. Never widen to "everyone" for it — that would
  # silently message a bigger audience than the merchant chose.
  def query(store_id, other) do
    Logger.warning("[segments] unknown segment #{inspect(other)}")
    Customer |> Ash.Query.filter(store_id == ^store_id and id == ^Ash.UUID.generate())
  end

  @spec counts(binary()) :: %{segment() => non_neg_integer()}
  def counts(store_id) do
    Map.new(@segments, fn segment ->
      {segment, store_id |> query(segment) |> Ash.count!(authorize?: false)}
    end)
  end

  # The paid_total at the 80th percentile among customers who have paid.
  # Two queries, no in-memory load of every paying customer's total: a COUNT
  # to find where the cutoff sits, then a single row (sorted, offset to that
  # rank) to read its paid_total.
  defp big_spender_floor(store_id) do
    paying = Customer |> Ash.Query.filter(store_id == ^store_id and paid_order_count >= 1)

    n = Ash.count!(paying, authorize?: false)

    if n < @min_buyers_for_big do
      nil
    else
      keep = max(1, div(n, 5))

      paying
      |> Ash.Query.sort(paid_total: :desc)
      |> Ash.Query.offset(keep - 1)
      |> Ash.Query.limit(1)
      |> Ash.Query.load(:paid_total)
      |> Ash.read_one!(authorize?: false)
      |> case do
        nil -> nil
        customer -> customer.paid_total || 0
      end
    end
  end

  defp days_ago(days), do: DateTime.add(DateTime.utc_now(), -days * 86_400, :second)
end
