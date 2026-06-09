defmodule Emakola.Orders.CheckoutLedgerTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    product = create_product!(store, title: "Ledger Cart Product")
    {:ok, store: store, product: product}
  end

  test "creates one owed ledger entry per supplier and none for merchant group", %{
    store: store,
    product: product
  } do
    supplier_a = create_supplier!(store)
    supplier_b = create_supplier!(store)

    drop_a =
      create_variant!(product, store,
        price: 10_000,
        sku: "L-DROP-A",
        supplier_id: supplier_a.id,
        cost_price: 800
      )

    drop_b =
      create_variant!(product, store,
        price: 8_000,
        sku: "L-DROP-B",
        supplier_id: supplier_b.id,
        cost_price: 500
      )

    own = create_variant!(product, store, price: 5_000, sku: "L-OWN", stock_quantity: 20)

    items = [
      %{variant_id: drop_a.id, quantity: 2},
      %{variant_id: drop_b.id, quantity: 1},
      %{variant_id: own.id, quantity: 3}
    ]

    assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

    fulfillments = Emakola.Orders.list_fulfillments_by_order!(order.id, authorize?: false)
    by_supplier = Map.new(fulfillments, fn f -> {f.supplier_id, f.id} end)

    {:ok, entries_a} = Emakola.Suppliers.list_ledger_entries_by_supplier(supplier_a.id)
    {:ok, entries_b} = Emakola.Suppliers.list_ledger_entries_by_supplier(supplier_b.id)

    all_entries =
      Emakola.Suppliers.SupplierLedgerEntry
      |> Ash.Query.filter(store_id == ^store.id)
      |> Ash.read!(authorize?: false)

    assert length(all_entries) == 2

    assert [entry_a] = entries_a
    assert [entry_b] = entries_b

    assert entry_a.amount_owed == 1600
    assert entry_a.status == :owed
    assert entry_a.fulfillment_id == by_supplier[supplier_a.id]

    assert entry_b.amount_owed == 500
    assert entry_b.status == :owed
    assert entry_b.fulfillment_id == by_supplier[supplier_b.id]

    # No ledger entry references the merchant (nil supplier) group
    refute Enum.any?(all_entries, fn e -> e.fulfillment_id == by_supplier[nil] end)
  end
end
