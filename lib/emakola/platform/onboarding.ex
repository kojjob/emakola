defmodule Emakola.Platform.Onboarding do
  @moduledoc """
  Platform onboarding-health overview: per-store milestone completion plus an
  aggregate funnel, computed with set-based queries (one read per milestone →
  a MapSet of qualifying store_ids, membership-tested per store — no N+1, no
  schema change).

  Milestones: products added, storefront live, payout registered, KYC verified,
  first order. Read-only; called by the platform admin with authorize?: false.
  """
  require Ash.Query

  alias Emakola.Catalog.Product
  alias Emakola.Orders.Order
  alias Emakola.Stores.Store
  alias Emakola.Stores.StorePayoutAccount
  alias Emakola.Stores.StoreVerification

  @milestones [:products, :live, :payout, :kyc, :first_order]

  @doc "Ordered milestone keys (display order)."
  def milestones, do: @milestones

  @doc """
  Returns `%{total_stores, funnel, stores}` where `funnel` maps each milestone
  to the count of stores that completed it, and `stores` is a list of
  `%{id, name, slug, milestones: %{...booleans}, completed}` sorted
  least-complete first.
  """
  @stalled_after_days 7

  @doc "Days of inactivity after which an incomplete store counts as stalled."
  def stalled_after_days, do: @stalled_after_days

  def overview do
    stores = Ash.read!(Store, authorize?: false)

    with_products = store_id_set(Product)
    with_payout = store_id_set(StorePayoutAccount)
    with_orders = store_id_set(Order)
    with_kyc = store_id_set(Ash.Query.filter(StoreVerification, status == :approved))

    latest_product_at = latest_inserted_at_by_store(Product)
    latest_order_at = latest_inserted_at_by_store(Order)
    today = Date.utc_today()

    rows =
      Enum.map(stores, fn store ->
        milestones = %{
          products: MapSet.member?(with_products, store.id),
          live: store.active == true and store.status == :active,
          payout: MapSet.member?(with_payout, store.id),
          kyc: MapSet.member?(with_kyc, store.id),
          first_order: MapSet.member?(with_orders, store.id)
        }

        completed = milestones |> Map.values() |> Enum.count(& &1)
        idle_days = idle_days(store, latest_product_at, latest_order_at, today)

        %{
          id: store.id,
          name: store.name,
          slug: store.slug,
          milestones: milestones,
          completed: completed,
          idle_days: idle_days,
          stalled?: completed < map_size(milestones) and idle_days >= @stalled_after_days
        }
      end)

    %{
      total_stores: length(stores),
      funnel: funnel(rows),
      stalled_count: Enum.count(rows, & &1.stalled?),
      stores: Enum.sort_by(rows, & &1.completed)
    }
  end

  # Last activity = the newest of store creation, latest product, latest
  # order — enough signal to spot merchants who signed up and went quiet.
  defp idle_days(store, latest_product_at, latest_order_at, today) do
    [store.inserted_at, latest_product_at[store.id], latest_order_at[store.id]]
    |> Enum.reject(&is_nil/1)
    |> Enum.max(DateTime)
    |> DateTime.to_date()
    |> then(&Date.diff(today, &1))
    |> max(0)
  end

  defp latest_inserted_at_by_store(resource) do
    resource
    |> Ash.Query.select([:store_id, :inserted_at])
    |> Ash.read!(authorize?: false)
    |> Enum.group_by(& &1.store_id, & &1.inserted_at)
    |> Map.new(fn {store_id, timestamps} -> {store_id, Enum.max(timestamps, DateTime)} end)
  end

  defp funnel(rows) do
    Map.new(@milestones, fn key -> {key, Enum.count(rows, & &1.milestones[key])} end)
  end

  # `queryable` is a resource module or an Ash.Query; select only store_id and
  # collapse to a MapSet for O(1) membership tests.
  defp store_id_set(queryable) do
    queryable
    |> Ash.Query.select([:store_id])
    |> Ash.read!(authorize?: false)
    |> MapSet.new(& &1.store_id)
  end
end
