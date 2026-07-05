defmodule Emakola.Catalog.ProductSearchVisibilityTest do
  @moduledoc """
  The storefront product search (`:search` read action, used by the store
  search overlay and the product-list search) must honor moderation. A product
  taken down by a platform moderator keeps `status == :active` but flips to
  `moderation_status == :taken_down`, so a status-only filter would leave it
  discoverable. Search must surface a product only when it is customer-visible:
  `status == :active` AND `moderation_status == :ok`.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Catalog
  alias Emakola.Catalog.Product
  alias Emakola.Factory

  setup do
    %{store: Factory.create_store!()}
  end

  defp search_active(store_id, query) do
    Product
    |> Ash.Query.for_read(:search, %{query: query, store_id: store_id, status: :active})
    |> Ash.read!(authorize?: false)
  end

  test "finds an active, moderation-ok product", %{store: store} do
    Factory.create_product!(store, %{title: "Kente Cloth", status: :active})

    results = search_active(store.id, "kente")
    assert Enum.any?(results, &(&1.title == "Kente Cloth"))
  end

  test "excludes a taken-down product even though its status is still :active", %{store: store} do
    product = Factory.create_product!(store, %{title: "Banned Widget", status: :active})
    {:ok, _} = Catalog.take_down_product(product, %{reason: "policy"}, authorize?: false)

    results = search_active(store.id, "banned")
    refute Enum.any?(results, &(&1.id == product.id))
  end
end
