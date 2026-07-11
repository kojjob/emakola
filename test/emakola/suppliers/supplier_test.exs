defmodule Emakola.Suppliers.SupplierTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  # -- Creation ---------------------------------------------------------------

  describe "create" do
    test "creates a supplier with valid attributes", %{store: store} do
      supplier =
        create_supplier!(store,
          name: "Acme Wholesale",
          contact_phone: "+233200000000",
          whatsapp_number: "+233200000000",
          contact_email: "supplier@example.com",
          payment_details: %{"momo_number" => "0240000000"},
          notes: "Reliable"
        )

      assert supplier.id
      assert supplier.name == "Acme Wholesale"
      assert supplier.store_id == store.id
      assert supplier.contact_phone == "+233200000000"
      assert supplier.whatsapp_number == "+233200000000"
      assert supplier.contact_email == "supplier@example.com"
      assert supplier.payment_details == %{"momo_number" => "0240000000"}
      assert supplier.notes == "Reliable"
      assert supplier.active == true
    end

    test "defaults active to true", %{store: store} do
      supplier = create_supplier!(store, name: "Default Supplier")
      assert supplier.active == true
    end

    test "rejects missing name", %{store: store} do
      assert {:error, _} =
               Emakola.Suppliers.Supplier
               |> Ash.Changeset.for_create(:create, %{store_id: store.id})
               |> Ash.create(authorize?: false)
    end

    test "rejects missing store_id" do
      assert {:error, _} =
               Emakola.Suppliers.Supplier
               |> Ash.Changeset.for_create(:create, %{name: "Test"})
               |> Ash.create(authorize?: false)
    end

    test "name is unique per store", %{store: store} do
      create_supplier!(store, name: "Acme Wholesale")

      assert {:error, _} =
               Emakola.Suppliers.Supplier
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 name: "Acme Wholesale"
               })
               |> Ash.create(authorize?: false)
    end

    test "same name allowed in different stores", %{store: store} do
      store2 = create_store!()
      create_supplier!(store, name: "Acme Wholesale")
      supplier2 = create_supplier!(store2, name: "Acme Wholesale")

      assert supplier2.name == "Acme Wholesale"
    end
  end

  # -- List by store ----------------------------------------------------------

  describe "list_by_store" do
    test "returns only that store's suppliers", %{store: store} do
      store2 = create_store!()
      create_supplier!(store, name: "Supplier A")
      create_supplier!(store, name: "Supplier B")
      create_supplier!(store2, name: "Supplier C")

      {:ok, suppliers} = Emakola.Suppliers.list_suppliers_by_store(store.id, authorize?: false)

      assert length(suppliers) == 2
      names = suppliers |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["Supplier A", "Supplier B"]
    end
  end

  # -- Linked wholesaler store (dropship settlement bridge) -------------------

  describe "linked_store_id" do
    test "links a supplier to a wholesaler store and loads the relationship", %{store: store} do
      wholesaler = create_store!(name: "Wholesaler Co")

      supplier = create_supplier!(store, name: "Bridged Supplier", linked_store_id: wholesaler.id)

      assert supplier.linked_store_id == wholesaler.id

      loaded = Ash.load!(supplier, :linked_store, authorize?: false)
      assert loaded.linked_store.id == wholesaler.id
    end

    test "defaults to nil for an ordinary external supplier", %{store: store} do
      supplier = create_supplier!(store, name: "External Supplier")
      assert is_nil(supplier.linked_store_id)
    end

    test "can be set on update", %{store: store} do
      wholesaler = create_store!(name: "Later Wholesaler")
      supplier = create_supplier!(store, name: "Upgradable Supplier")

      {:ok, updated} =
        supplier
        |> Ash.Changeset.for_update(:update, %{linked_store_id: wholesaler.id})
        |> Ash.update(authorize?: false)

      assert updated.linked_store_id == wholesaler.id
    end
  end

  # -- Update -----------------------------------------------------------------

  describe "update" do
    test "updates supplier attributes", %{store: store} do
      supplier = create_supplier!(store, name: "Acme")

      {:ok, updated} =
        supplier
        |> Ash.Changeset.for_update(:update, %{notes: "Updated", active: false})
        |> Ash.update(authorize?: false)

      assert updated.notes == "Updated"
      assert updated.active == false
    end
  end
end
