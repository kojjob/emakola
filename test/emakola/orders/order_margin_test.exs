defmodule Emakola.Orders.OrderMarginTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    product = create_product!(store, title: "Margin Product")
    {:ok, store: store, product: product}
  end

  test "margin sums (unit_price - cost_price) * quantity across line items", %{
    store: store,
    product: product
  } do
    supplier = create_supplier!(store)

    drop =
      create_variant!(product, store,
        price: 5_000,
        sku: "M-DROP",
        supplier_id: supplier.id,
        cost_price: 800
      )

    own = create_variant!(product, store, price: 3_000, sku: "M-OWN", stock_quantity: 20)

    items = [
      %{variant_id: drop.id, quantity: 2},
      %{variant_id: own.id, quantity: 1}
    ]

    assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

    loaded = Ash.load!(order, :margin, authorize?: false)
    # (5000 - 800) * 2 + (3000 - 0) * 1 = 8400 + 3000 = 11400
    assert loaded.margin == 11_400
  end

  test "margin counts full unit_price for a line whose cost_price is nil", %{
    store: store,
    product: product
  } do
    supplier = create_supplier!(store)

    # Supplier variant with no recorded cost — exercises the (cost_price || 0)
    # branch: the whole unit_price counts toward margin.
    no_cost =
      create_variant!(product, store,
        price: 4_000,
        sku: "M-NOCOST",
        supplier_id: supplier.id,
        cost_price: nil
      )

    items = [%{variant_id: no_cost.id, quantity: 3}]

    assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

    loaded = Ash.load!(order, :margin, authorize?: false)
    # (4000 - 0) * 3 = 12000
    assert loaded.margin == 12_000
  end

  test "margin is zero for an order with no line items", %{store: store} do
    order = create_order!(store)
    loaded = Ash.load!(order, :margin, authorize?: false)
    assert loaded.margin == 0
  end
end
