defmodule Emakola.Orders.LineItemTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    product = create_product!(store, title: "African Print Shirt")
    variant = create_variant!(product, store, price: 15_000, sku: "APS-001", stock_quantity: 50)
    order = create_order!(store)
    {:ok, store: store, product: product, variant: variant, order: order}
  end

  # -- Creation -------------------------------------------------------

  describe "create" do
    test "snapshots variant price and product title", %{
      store: store,
      variant: variant,
      order: order,
      product: product
    } do
      line_item =
        Emakola.Orders.LineItem
        |> Ash.Changeset.for_create(:create, %{
          order_id: order.id,
          store_id: store.id,
          variant_id: variant.id,
          quantity: 2
        })
        |> Ash.create!(authorize?: false)

      assert line_item.product_title == product.title
      assert line_item.variant_sku == variant.sku
      assert line_item.unit_price == variant.price
      assert line_item.quantity == 2
      assert line_item.line_total == 30_000
    end

    test "calculates line_total as unit_price * quantity", %{
      store: store,
      variant: variant,
      order: order
    } do
      line_item =
        Emakola.Orders.LineItem
        |> Ash.Changeset.for_create(:create, %{
          order_id: order.id,
          store_id: store.id,
          variant_id: variant.id,
          quantity: 5
        })
        |> Ash.create!(authorize?: false)

      assert line_item.line_total == 75_000
    end

    test "rejects quantity of zero", %{store: store, variant: variant, order: order} do
      assert {:error, _} =
               Emakola.Orders.LineItem
               |> Ash.Changeset.for_create(:create, %{
                 order_id: order.id,
                 store_id: store.id,
                 variant_id: variant.id,
                 quantity: 0
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects negative quantity", %{store: store, variant: variant, order: order} do
      assert {:error, _} =
               Emakola.Orders.LineItem
               |> Ash.Changeset.for_create(:create, %{
                 order_id: order.id,
                 store_id: store.id,
                 variant_id: variant.id,
                 quantity: -1
               })
               |> Ash.create(authorize?: false)
    end
  end
end
