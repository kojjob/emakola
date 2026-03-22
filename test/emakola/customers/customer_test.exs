defmodule Emakola.Customers.CustomerTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  # -- Creation -------------------------------------------------------

  describe "create" do
    test "creates a customer with valid attributes", %{store: store} do
      customer =
        create_customer!(store,
          email: "ama@example.com",
          name: "Ama Mensah",
          phone: "+233244000111"
        )

      assert customer.id
      assert customer.store_id == store.id
      assert to_string(customer.email) == "ama@example.com"
      assert customer.name == "Ama Mensah"
      assert customer.phone == "+233244000111"
    end

    test "email is case-insensitive for uniqueness", %{store: store} do
      create_customer!(store, email: "AMa@Example.COM")

      # Same email with different casing should be rejected (ci_string uniqueness)
      assert {:error, _} =
               Emakola.Customers.Customer
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 email: "ama@example.com",
                 name: "Another"
               })
               |> Ash.create()
    end

    test "requires email", %{store: store} do
      assert {:error, _} =
               Emakola.Customers.Customer
               |> Ash.Changeset.for_create(:create, %{store_id: store.id, name: "No Email"})
               |> Ash.create()
    end

    test "requires store_id" do
      assert {:error, _} =
               Emakola.Customers.Customer
               |> Ash.Changeset.for_create(:create, %{email: "test@example.com"})
               |> Ash.create()
    end
  end

  # -- Uniqueness -----------------------------------------------------

  describe "email uniqueness" do
    test "rejects duplicate email within same store", %{store: store} do
      create_customer!(store, email: "dup@example.com")

      assert {:error, _} =
               Emakola.Customers.Customer
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 email: "dup@example.com",
                 name: "Dup"
               })
               |> Ash.create()
    end

    test "allows same email in different stores", %{store: store} do
      store2 = create_store!()
      create_customer!(store, email: "shared@example.com")
      customer2 = create_customer!(store2, email: "shared@example.com")

      assert customer2.id
      assert customer2.store_id == store2.id
    end
  end

  # -- Update ---------------------------------------------------------

  describe "update" do
    test "updates customer name and phone", %{store: store} do
      customer = create_customer!(store, email: "update@example.com", name: "Old Name")

      updated =
        customer
        |> Ash.Changeset.for_update(:update, %{name: "New Name", phone: "+233201234567"})
        |> Ash.update!()

      assert updated.name == "New Name"
      assert updated.phone == "+233201234567"
    end
  end
end
