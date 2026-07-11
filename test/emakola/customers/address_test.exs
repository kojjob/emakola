defmodule Emakola.Customers.AddressTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    customer = create_customer!(store, email: "addr@example.com", name: "Addr Test")
    {:ok, store: store, customer: customer}
  end

  # -- Creation -------------------------------------------------------

  describe "create" do
    test "creates an address with all fields", %{store: store, customer: customer} do
      address =
        create_address!(customer, store,
          label: "Home",
          first_name: "Kwame",
          last_name: "Asante",
          line_1: "12 Oxford Street",
          line_2: "Osu",
          city: "Accra",
          region: "Greater Accra",
          country: "GH",
          postal_code: "GA-123",
          phone: "+233244000111"
        )

      assert address.id
      assert address.customer_id == customer.id
      assert address.store_id == store.id
      assert address.label == "Home"
      assert address.line_1 == "12 Oxford Street"
      assert address.city == "Accra"
      assert address.country == "GH"
      assert address.is_default == false
    end

    test "creates with minimal required fields", %{store: store, customer: customer} do
      address =
        create_address!(customer, store,
          line_1: "15 Kanda Highway",
          city: "Accra"
        )

      assert address.id
      assert address.line_1 == "15 Kanda Highway"
      assert address.city == "Accra"
      assert address.country == "GH"
      assert is_nil(address.postal_code)
    end

    test "requires line_1", %{store: store, customer: customer} do
      assert {:error, _} =
               Emakola.Customers.Address
               |> Ash.Changeset.for_create(:create, %{
                 customer_id: customer.id,
                 store_id: store.id,
                 city: "Accra"
               })
               |> Ash.create(authorize?: false)
    end

    test "requires city", %{store: store, customer: customer} do
      assert {:error, _} =
               Emakola.Customers.Address
               |> Ash.Changeset.for_create(:create, %{
                 customer_id: customer.id,
                 store_id: store.id,
                 line_1: "Some Street"
               })
               |> Ash.create(authorize?: false)
    end

    test "country defaults to GH", %{store: store, customer: customer} do
      address = create_address!(customer, store, line_1: "Test St", city: "Kumasi")
      assert address.country == "GH"
    end
  end

  # -- Update ---------------------------------------------------------

  describe "update" do
    test "updates address fields", %{store: store, customer: customer} do
      address = create_address!(customer, store, line_1: "Old Street", city: "Accra")

      updated =
        address
        |> Ash.Changeset.for_update(:update, %{line_1: "New Street", region: "Greater Accra"})
        |> Ash.update!(authorize?: false)

      assert updated.line_1 == "New Street"
      assert updated.region == "Greater Accra"
    end
  end

  # -- Destroy --------------------------------------------------------

  describe "destroy" do
    test "deletes an address", %{store: store, customer: customer} do
      address = create_address!(customer, store, line_1: "Delete Me", city: "Accra")

      assert :ok =
               address |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy(authorize?: false)

      assert {:error, _} = Ash.get(Emakola.Customers.Address, address.id)
    end
  end

  # -- list_by_customer -----------------------------------------------

  describe "list_by_customer" do
    test "returns addresses for a customer", %{store: store, customer: customer} do
      a1 = create_address!(customer, store, line_1: "Addr 1", city: "Accra")
      a2 = create_address!(customer, store, line_1: "Addr 2", city: "Kumasi")

      # Different customer's address
      other = create_customer!(store, email: "other@example.com")
      _other_addr = create_address!(other, store, line_1: "Other", city: "Tamale")

      results =
        Emakola.Customers.Address
        |> Ash.ActionInput.for_action(:list_by_customer, %{
          customer_id: customer.id,
          store_id: store.id
        })
        |> Ash.run_action!()

      ids = Enum.map(results, & &1.id)
      assert length(ids) == 2
      assert a1.id in ids
      assert a2.id in ids
    end
  end

  # -- set_as_default -------------------------------------------------

  describe "set_as_default" do
    test "sets an address as default and clears previous default", %{
      store: store,
      customer: customer
    } do
      a1 = create_address!(customer, store, line_1: "First", city: "Accra")

      # Set a1 as default first
      Emakola.Customers.Address
      |> Ash.ActionInput.for_action(:set_as_default, %{address_id: a1.id})
      |> Ash.run_action!()

      a2 = create_address!(customer, store, line_1: "Second", city: "Kumasi")

      # Set a2 as default
      Emakola.Customers.Address
      |> Ash.ActionInput.for_action(:set_as_default, %{address_id: a2.id})
      |> Ash.run_action!()

      # a2 should now be default
      reloaded_a2 =
        Ash.get!(Emakola.Customers.Address, a2.id, authorize?: false, authorize?: false)

      assert reloaded_a2.is_default == true

      # a1 should no longer be default
      reloaded_a1 =
        Ash.get!(Emakola.Customers.Address, a1.id, authorize?: false, authorize?: false)

      assert reloaded_a1.is_default == false
    end

    test "set_as_default when only one address exists", %{store: store, customer: customer} do
      addr = create_address!(customer, store, line_1: "Only One", city: "Accra")

      Emakola.Customers.Address
      |> Ash.ActionInput.for_action(:set_as_default, %{address_id: addr.id})
      |> Ash.run_action!()

      reloaded =
        Ash.get!(Emakola.Customers.Address, addr.id, authorize?: false, authorize?: false)

      assert reloaded.is_default == true
    end
  end
end
