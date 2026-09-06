defmodule Emakola.Customers.CustomerTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

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

    test "creates a customer with tags", %{store: store} do
      customer = create_customer!(store, email: "tagged@example.com", tags: ["vip", "wholesale"])

      assert customer.tags == ["vip", "wholesale"]
    end

    test "tags default to empty list", %{store: store} do
      customer = create_customer!(store, email: "notags@example.com")

      assert customer.tags == []
    end

    test "email is case-insensitive for uniqueness", %{store: store} do
      create_customer!(store, email: "AMa@Example.COM")

      assert {:error, _} =
               Emakola.Customers.Customer
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 email: "ama@example.com",
                 name: "Another"
               })
               |> Ash.create(authorize?: false)
    end

    test "requires email", %{store: store} do
      assert {:error, _} =
               Emakola.Customers.Customer
               |> Ash.Changeset.for_create(:create, %{store_id: store.id, name: "No Email"})
               |> Ash.create(authorize?: false)
    end

    test "requires store_id" do
      assert {:error, _} =
               Emakola.Customers.Customer
               |> Ash.Changeset.for_create(:create, %{email: "test@example.com"})
               |> Ash.create(authorize?: false)
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
               |> Ash.create(authorize?: false)
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
        |> Ash.update!(authorize?: false)

      assert updated.name == "New Name"
      assert updated.phone == "+233201234567"
    end

    test "updates customer tags", %{store: store} do
      customer = create_customer!(store, email: "tags@example.com", tags: ["vip"])

      updated =
        customer
        |> Ash.Changeset.for_update(:update, %{tags: ["vip", "wholesale"]})
        |> Ash.update!(authorize?: false)

      assert updated.tags == ["vip", "wholesale"]
    end
  end

  # -- touch_last_order -----------------------------------------------

  describe "touch_last_order" do
    test "sets last_order_at to current time", %{store: store} do
      customer = create_customer!(store, email: "order@example.com")
      assert is_nil(customer.last_order_at)

      updated =
        customer
        |> Ash.Changeset.for_update(:touch_last_order)
        |> Ash.update!(authorize?: false)

      assert %DateTime{} = updated.last_order_at
    end
  end

  describe "backdate_last_order policy" do
    test "a customer, even acting on their own row, cannot call it", %{store: store} do
      customer = create_customer!(store, email: "backdate@example.com")

      assert {:error, %Ash.Error.Forbidden{}} =
               customer
               |> Ash.Changeset.for_update(
                 :backdate_last_order,
                 %{last_order_at: DateTime.utc_now()},
                 actor: customer
               )
               |> Ash.update()

      refute Ash.reload!(customer, authorize?: false).last_order_at
    end
  end

  # -- list_by_store --------------------------------------------------

  describe "list_by_store" do
    test "returns customers for a store sorted by newest first", %{store: store} do
      c1 = create_customer!(store, email: "first@example.com")
      c2 = create_customer!(store, email: "second@example.com")

      # Different store customer should not appear
      other_store = create_store!()
      _other = create_customer!(other_store, email: "other@example.com")

      results =
        Emakola.Customers.Customer
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!(authorize?: false)

      ids = Enum.map(results, & &1.id)
      assert length(ids) == 2
      # Newest first
      assert hd(ids) == c2.id
      assert List.last(ids) == c1.id
    end
  end

  # -- search ---------------------------------------------------------

  describe "search" do
    test "searches by name", %{store: store} do
      create_customer!(store, email: "kwame@example.com", name: "Kwame Asante")
      create_customer!(store, email: "ama@example.com", name: "Ama Mensah")

      results =
        Emakola.Customers.Customer
        |> Ash.Query.for_read(:search, %{query: "kwame", store_id: store.id})
        |> Ash.read!(authorize?: false)

      assert length(results) == 1
      assert hd(results).name == "Kwame Asante"
    end

    test "searches by email", %{store: store} do
      create_customer!(store, email: "findme@shop.com", name: "Find Me")
      create_customer!(store, email: "other@shop.com", name: "Other")

      results =
        Emakola.Customers.Customer
        |> Ash.Query.for_read(:search, %{query: "findme", store_id: store.id})
        |> Ash.read!(authorize?: false)

      assert length(results) == 1
    end

    test "searches by phone", %{store: store} do
      create_customer!(store, email: "phone@example.com", phone: "+233244123456")

      results =
        Emakola.Customers.Customer
        |> Ash.Query.for_read(:search, %{query: "244123", store_id: store.id})
        |> Ash.read!(authorize?: false)

      assert length(results) == 1
    end

    test "search is scoped to store", %{store: store} do
      other_store = create_store!()
      create_customer!(other_store, email: "cross@example.com", name: "Cross Store")

      results =
        Emakola.Customers.Customer
        |> Ash.Query.for_read(:search, %{query: "cross", store_id: store.id})
        |> Ash.read!(authorize?: false)

      assert Enum.empty?(results)
    end
  end

  # -- find_or_create -------------------------------------------------

  describe "find_or_create" do
    test "returns existing customer when email matches", %{store: store} do
      existing = create_customer!(store, email: "existing@example.com", name: "Existing")

      result =
        Emakola.Customers.Customer
        |> Ash.ActionInput.for_action(:find_or_create, %{
          email: "existing@example.com",
          store_id: store.id
        })
        |> Ash.run_action!()

      assert result.id == existing.id
    end

    test "creates new customer when no match", %{store: store} do
      result =
        Emakola.Customers.Customer
        |> Ash.ActionInput.for_action(:find_or_create, %{
          email: "brand-new@example.com",
          store_id: store.id,
          name: "Brand New",
          phone: "+233201111111"
        })
        |> Ash.run_action!()

      assert result.id
      assert to_string(result.email) == "brand-new@example.com"
      assert result.name == "Brand New"
      assert result.phone == "+233201111111"
      assert result.store_id == store.id
    end

    test "creates with only email when no name/phone provided", %{store: store} do
      result =
        Emakola.Customers.Customer
        |> Ash.ActionInput.for_action(:find_or_create, %{
          email: "minimal@example.com",
          store_id: store.id
        })
        |> Ash.run_action!()

      assert result.id
      assert to_string(result.email) == "minimal@example.com"
      assert is_nil(result.name)
    end

    test "find_or_create is case-insensitive on email", %{store: store} do
      existing = create_customer!(store, email: "case@example.com")

      result =
        Emakola.Customers.Customer
        |> Ash.ActionInput.for_action(:find_or_create, %{
          email: "CASE@EXAMPLE.COM",
          store_id: store.id
        })
        |> Ash.run_action!()

      assert result.id == existing.id
    end

    test "find_or_create is scoped to store", %{store: store} do
      other_store = create_store!()
      _other = create_customer!(other_store, email: "scoped@example.com")

      result =
        Emakola.Customers.Customer
        |> Ash.ActionInput.for_action(:find_or_create, %{
          email: "scoped@example.com",
          store_id: store.id
        })
        |> Ash.run_action!()

      # Should create a new one in this store, not find the other store's customer
      assert result.store_id == store.id
    end
  end
end
