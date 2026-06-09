defmodule Emakola.Suppliers.SupplierLedgerEntryTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    supplier = create_supplier!(store)
    order = create_order!(store)
    fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)
    {:ok, store: store, supplier: supplier, fulfillment: fulfillment}
  end

  describe "create" do
    test "creates a ledger entry with valid attributes", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx

      entry =
        create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 2500)

      assert entry.id
      assert entry.store_id == store.id
      assert entry.supplier_id == supplier.id
      assert entry.fulfillment_id == fulfillment.id
      assert entry.amount_owed == 2500
      assert entry.status == :owed
      assert is_nil(entry.paid_at)
    end

    test "defaults status to owed", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store)
      assert entry.status == :owed
    end

    test "rejects negative amount_owed", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx

      assert {:error, _} =
               Emakola.Suppliers.SupplierLedgerEntry
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 supplier_id: supplier.id,
                 fulfillment_id: fulfillment.id,
                 amount_owed: -1
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects missing store_id", ctx do
      %{supplier: supplier, fulfillment: fulfillment} = ctx

      assert {:error, _} =
               Emakola.Suppliers.SupplierLedgerEntry
               |> Ash.Changeset.for_create(:create, %{
                 supplier_id: supplier.id,
                 fulfillment_id: fulfillment.id,
                 amount_owed: 1000
               })
               |> Ash.create(authorize?: false)
    end

    test "is unique per fulfillment", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      create_supplier_ledger_entry!(supplier, fulfillment, store)

      assert {:error, _} =
               Emakola.Suppliers.SupplierLedgerEntry
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 supplier_id: supplier.id,
                 fulfillment_id: fulfillment.id,
                 amount_owed: 1000
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "mark_paid" do
    test "sets status to paid and stamps paid_at", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store)

      {:ok, paid} =
        entry
        |> Ash.Changeset.for_update(:mark_paid, %{})
        |> Ash.update(authorize?: false)

      assert paid.status == :paid
      assert %DateTime{} = paid.paid_at
    end

    test "rejects marking an already-paid entry", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store)

      {:ok, paid} =
        entry
        |> Ash.Changeset.for_update(:mark_paid, %{})
        |> Ash.update(authorize?: false)

      assert {:error, _} =
               paid
               |> Ash.Changeset.for_update(:mark_paid, %{})
               |> Ash.update(authorize?: false)
    end
  end

  describe "list_by_supplier" do
    test "returns that supplier's entries newest first", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      order2 = create_order!(store)
      fulfillment2 = create_fulfillment!(order2, store, supplier_id: supplier.id)

      create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1000)
      create_supplier_ledger_entry!(supplier, fulfillment2, store, amount_owed: 2000)

      other_supplier = create_supplier!(store)
      order3 = create_order!(store)
      fulfillment3 = create_fulfillment!(order3, store, supplier_id: other_supplier.id)
      create_supplier_ledger_entry!(other_supplier, fulfillment3, store, amount_owed: 9999)

      {:ok, entries} = Emakola.Suppliers.list_ledger_entries_by_supplier(supplier.id)

      assert length(entries) == 2
      assert Enum.all?(entries, &(&1.supplier_id == supplier.id))
      # Declared sort is inserted_at: :desc — newest (the 2000 entry) first.
      assert List.first(entries).amount_owed == 2000
    end
  end
end
