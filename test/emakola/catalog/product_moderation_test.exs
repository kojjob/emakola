defmodule Emakola.Catalog.ProductModerationTest do
  @moduledoc """
  Platform content moderation for products: take_down/reinstate are platform-only
  (merchants can't reverse), and a taken-down product disappears from the
  customer-facing reads while staying visible to admin reads.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Catalog
  alias Emakola.Factory

  describe "take_down / reinstate" do
    setup do
      store = Factory.create_store!()
      %{store: store, product: Factory.create_product!(store, %{status: :active})}
    end

    test "take_down sets moderation_status, reason, and timestamp", %{product: product} do
      assert {:ok, p} =
               Catalog.take_down_product(product, %{reason: "Counterfeit"}, authorize?: false)

      assert p.moderation_status == :taken_down
      assert p.moderation_reason == "Counterfeit"
      assert %DateTime{} = p.moderation_at
    end

    test "take_down requires a reason", %{product: product} do
      assert {:error, _} = Catalog.take_down_product(product, %{}, authorize?: false)
    end

    test "reinstate restores :ok and clears the reason", %{product: product} do
      {:ok, down} = Catalog.take_down_product(product, %{reason: "x"}, authorize?: false)
      assert {:ok, p} = Catalog.reinstate_product(down, %{}, authorize?: false)
      assert p.moderation_status == :ok
      assert is_nil(p.moderation_reason)
    end

    test "a merchant actor cannot take down a product (platform-only)" do
      {merchant, store} = Factory.create_merchant_with_store!()
      product = Factory.create_product!(store, %{status: :active})

      assert {:error, _} =
               Catalog.take_down_product(product, %{reason: "x"},
                 actor: merchant,
                 authorize?: true
               )
    end
  end

  describe "storefront visibility" do
    setup do
      store = Factory.create_store!()
      %{store: store, product: Factory.create_product!(store, %{status: :active})}
    end

    test "get_by_slug returns an ok product, hides a taken-down one", %{
      store: store,
      product: product
    } do
      assert {:ok, %{id: id}} =
               Catalog.get_product_by_slug(store.id, product.slug, authorize?: false)

      assert id == product.id

      {:ok, _} = Catalog.take_down_product(product, %{reason: "x"}, authorize?: false)
      assert {:error, _} = Catalog.get_product_by_slug(store.id, product.slug, authorize?: false)
    end

    test "active list excludes taken-down; admin list still includes it", %{
      store: store,
      product: product
    } do
      {:ok, active} =
        Catalog.list_products_by_store_and_status(store.id, :active, authorize?: false)

      assert product.id in Enum.map(active, & &1.id)

      {:ok, _} = Catalog.take_down_product(product, %{reason: "x"}, authorize?: false)

      {:ok, active2} =
        Catalog.list_products_by_store_and_status(store.id, :active, authorize?: false)

      refute product.id in Enum.map(active2, & &1.id)

      {:ok, admin} = Catalog.list_products_admin(store.id, authorize?: false)
      assert product.id in Enum.map(admin, & &1.id)
    end
  end
end
