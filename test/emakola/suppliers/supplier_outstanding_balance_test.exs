defmodule Emakola.Suppliers.SupplierOutstandingBalanceTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    supplier = create_supplier!(store)
    {:ok, store: store, supplier: supplier}
  end

  defp owed_fulfillment(store, supplier) do
    order = create_order!(store)
    create_fulfillment!(order, store, supplier_id: supplier.id)
  end

  test "sums owed entries for the supplier", %{store: store, supplier: supplier} do
    create_supplier_ledger_entry!(supplier, owed_fulfillment(store, supplier), store,
      amount_owed: 1000
    )

    create_supplier_ledger_entry!(supplier, owed_fulfillment(store, supplier), store,
      amount_owed: 2500
    )

    loaded = Ash.load!(supplier, :outstanding_balance, authorize?: false)
    assert loaded.outstanding_balance == 3500
  end

  test "excludes paid entries from the balance", %{store: store, supplier: supplier} do
    paid_entry =
      create_supplier_ledger_entry!(supplier, owed_fulfillment(store, supplier), store,
        amount_owed: 1000
      )

    create_supplier_ledger_entry!(supplier, owed_fulfillment(store, supplier), store,
      amount_owed: 2500
    )

    paid_entry
    |> Ash.Changeset.for_update(:mark_paid, %{})
    |> Ash.update!(authorize?: false)

    loaded = Ash.load!(supplier, :outstanding_balance, authorize?: false)
    assert loaded.outstanding_balance == 2500
  end

  test "is zero for a supplier with no entries", %{supplier: supplier} do
    loaded = Ash.load!(supplier, :outstanding_balance, authorize?: false)
    assert loaded.outstanding_balance == 0
  end
end
