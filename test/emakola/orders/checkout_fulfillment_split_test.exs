defmodule Emakola.Orders.CheckoutFulfillmentSplitTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    product = create_product!(store, title: "Mixed Cart Product")
    {:ok, store: store, product: product}
  end

  describe "fulfillment split at checkout" do
    test "splits a mixed cart into one fulfillment per supplier plus merchant group", %{
      store: store,
      product: product
    } do
      supplier_a = create_supplier!(store)
      supplier_b = create_supplier!(store)

      # Dropshipped variants (supplier_id present → track_inventory false)
      drop_a =
        create_variant!(product, store,
          price: 10_000,
          sku: "DROP-A",
          supplier_id: supplier_a.id,
          cost_price: 6_000
        )

      drop_b =
        create_variant!(product, store,
          price: 8_000,
          sku: "DROP-B",
          supplier_id: supplier_b.id,
          cost_price: 5_000
        )

      # Own-stock tracked variant
      own =
        create_variant!(product, store, price: 5_000, sku: "OWN", stock_quantity: 20)

      items = [
        %{variant_id: drop_a.id, quantity: 2},
        %{variant_id: drop_b.id, quantity: 1},
        %{variant_id: own.id, quantity: 3}
      ]

      assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

      fulfillments = Emakola.Orders.list_fulfillments_by_order!(order.id, authorize?: false)
      assert length(fulfillments) == 3

      supplier_ids = fulfillments |> Enum.map(& &1.supplier_id) |> Enum.sort()
      assert Enum.sort([supplier_a.id, supplier_b.id, nil]) == supplier_ids

      # Each line item assigned to the fulfillment matching its variant's supplier
      by_supplier = Map.new(fulfillments, fn f -> {f.supplier_id, f.id} end)

      line_items =
        order
        |> Ash.load!(:line_items, authorize?: false)
        |> Map.get(:line_items)

      li_by_variant = Map.new(line_items, fn li -> {li.variant_id, li} end)

      assert li_by_variant[drop_a.id].fulfillment_id == by_supplier[supplier_a.id]
      assert li_by_variant[drop_b.id].fulfillment_id == by_supplier[supplier_b.id]
      assert li_by_variant[own.id].fulfillment_id == by_supplier[nil]

      # Dropshipped line items snapshot the supplier cost; own-stock is nil
      assert li_by_variant[drop_a.id].cost_price == 6_000
      assert li_by_variant[drop_b.id].cost_price == 5_000
      assert is_nil(li_by_variant[own.id].cost_price)
    end

    test "decrements own-stock but not dropshipped variant stock", %{
      store: store,
      product: product
    } do
      supplier = create_supplier!(store)

      drop =
        create_variant!(product, store,
          price: 10_000,
          sku: "DROP-S",
          supplier_id: supplier.id,
          cost_price: 6_000
        )

      own = create_variant!(product, store, price: 5_000, sku: "OWN-S", stock_quantity: 20)

      items = [
        %{variant_id: drop.id, quantity: 5},
        %{variant_id: own.id, quantity: 4}
      ]

      assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])
      # Stock decrements on payment confirmation, not at checkout.
      {:ok, _} = Emakola.Orders.confirm_order(order, authorize?: false)

      reloaded_own = Ash.get!(Emakola.Catalog.Variant, own.id, authorize?: false)
      reloaded_drop = Ash.get!(Emakola.Catalog.Variant, drop.id, authorize?: false)

      assert reloaded_own.stock_quantity == 16
      # Dropshipped variant stock untouched (defaults to 0, never decremented)
      assert reloaded_drop.stock_quantity == 0
    end

    test "pure-dropship cart checks out without a stock check", %{
      store: store,
      product: product
    } do
      supplier = create_supplier!(store)

      drop =
        create_variant!(product, store,
          price: 12_000,
          sku: "DROP-ONLY",
          supplier_id: supplier.id,
          cost_price: 7_000
        )

      items = [%{variant_id: drop.id, quantity: 99}]

      assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])
      assert order.subtotal == 12_000 * 99

      fulfillments = Emakola.Orders.list_fulfillments_by_order!(order.id, authorize?: false)
      assert [%{supplier_id: sid}] = fulfillments
      assert sid == supplier.id
    end

    test "an unavailable dropship variant cannot be checked out", %{
      store: store,
      product: product
    } do
      supplier = create_supplier!(store)

      variant =
        create_variant!(product, store,
          price: 5_000,
          sku: "DROP-UNAVAIL",
          supplier_id: supplier.id,
          available: false
        )

      # Dropship variants are untracked, so the plain stock check would pass —
      # but the supplier marked it unavailable, so checkout must reject it.
      assert {:error, :insufficient_stock} =
               Emakola.Orders.CheckoutService.checkout!(
                 store.id,
                 [%{variant_id: variant.id, quantity: 1}],
                 []
               )
    end
  end
end
