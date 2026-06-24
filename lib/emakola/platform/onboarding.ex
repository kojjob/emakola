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
  def overview do
    stores = Ash.read!(Store, authorize?: false)

    with_products = store_id_set(Product)
    with_payout = store_id_set(StorePayoutAccount)
    with_orders = store_id_set(Order)
    with_kyc = store_id_set(Ash.Query.filter(StoreVerification, status == :approved))

    rows =
      Enum.map(stores, fn store ->
        milestones = %{
          products: MapSet.member?(with_products, store.id),
          live: store.active == true and store.status == :active,
          payout: MapSet.member?(with_payout, store.id),
          kyc: MapSet.member?(with_kyc, store.id),
          first_order: MapSet.member?(with_orders, store.id)
        }

        %{
          id: store.id,
          name: store.name,
          slug: store.slug,
          milestones: milestones,
          completed: milestones |> Map.values() |> Enum.count(& &1)
        }
      end)

    %{
      total_stores: length(stores),
      funnel: funnel(rows),
      stores: Enum.sort_by(rows, & &1.completed)
    }
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
