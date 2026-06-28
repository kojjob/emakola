defmodule Emakola.Catalog.ProductStorefrontReadTest do
  @moduledoc """
  The storefront single-product read (`get_active_product/2`) backs the
  add-to-cart path. It must surface a product only when it is customer-visible —
  `status == :active` AND `moderation_status == :ok` — and only within the
  requesting store. A draft / archived / taken-down / other-store product must
  never resolve, even when the caller knows its id.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Catalog
  alias Emakola.Factory

  setup do
    %{store: Factory.create_store!()}
  end

  test "returns an active, moderation-ok product in the requested store", %{store: store} do
    product = Factory.create_product!(store, %{status: :active})

    assert {:ok, %{id: id}} = Catalog.get_active_product(store.id, product.id, authorize?: false)
    assert id == product.id
  end

  test "rejects a draft product", %{store: store} do
    product = Factory.create_product!(store, %{status: :draft})
    assert {:error, _} = Catalog.get_active_product(store.id, product.id, authorize?: false)
  end

  test "rejects an archived product", %{store: store} do
    product = Factory.create_product!(store, %{status: :archived})
    assert {:error, _} = Catalog.get_active_product(store.id, product.id, authorize?: false)
  end

  test "rejects a taken-down product", %{store: store} do
    product = Factory.create_product!(store, %{status: :active})
    {:ok, _} = Catalog.take_down_product(product, %{reason: "x"}, authorize?: false)
    assert {:error, _} = Catalog.get_active_product(store.id, product.id, authorize?: false)
  end

  test "rejects a product belonging to a different store", %{store: store} do
    other_store = Factory.create_store!()
    product = Factory.create_product!(other_store, %{status: :active})
    assert {:error, _} = Catalog.get_active_product(store.id, product.id, authorize?: false)
  end
end
