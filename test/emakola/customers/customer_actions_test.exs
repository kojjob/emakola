defmodule Emakola.Customers.CustomerActionsTest do
  @moduledoc "Tests for Customer read actions: list_by_store, search, get_by_id, and aggregates."
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  # -- list_by_store ---------------------------------------------------------

  describe "list_by_store" do
    test "returns customers for the given store", %{store: store} do
      c1 = create_customer!(store, name: "Ama Mensah", email: "ama@example.com")
      c2 = create_customer!(store, name: "Kofi Boateng", email: "kofi@example.com")

      # Different store should not appear
      other_store = create_store!()
      _c3 = create_customer!(other_store, name: "Yaw Owusu", email: "yaw@example.com")

      {:ok, customers} = Emakola.Customers.list_customers_by_store(store.id, authorize?: false)

      customer_ids = Enum.map(customers, & &1.id)
      assert c1.id in customer_ids
      assert c2.id in customer_ids
      assert length(customers) == 2
    end

    test "returns customers sorted by inserted_at desc", %{store: store} do
      c1 = create_customer!(store, name: "First", email: "first@example.com")

      # Small delay to ensure different timestamps
      Process.sleep(10)
      c2 = create_customer!(store, name: "Second", email: "second@example.com")

      {:ok, customers} = Emakola.Customers.list_customers_by_store(store.id, authorize?: false)

      assert hd(customers).id == c2.id
      assert List.last(customers).id == c1.id
    end

    test "returns empty list for store with no customers" do
      empty_store = create_store!()

      {:ok, customers} =
        Emakola.Customers.list_customers_by_store(empty_store.id, authorize?: false)

      assert customers == []
    end
  end

  # -- search ----------------------------------------------------------------

  describe "search" do
    test "searches by name (case insensitive)", %{store: store} do
      create_customer!(store, name: "Ama Mensah", email: "ama@example.com")
      create_customer!(store, name: "Kofi Boateng", email: "kofi@example.com")

      {:ok, results} = Emakola.Customers.search_customers(store.id, "ama", authorize?: false)

      assert length(results) == 1
      assert hd(results).name == "Ama Mensah"
    end

    test "searches by email (case insensitive)", %{store: store} do
      create_customer!(store, name: "Test User", email: "ama.mensah@example.com")
      create_customer!(store, name: "Other User", email: "kofi@example.com")

      {:ok, results} =
        Emakola.Customers.search_customers(store.id, "ama.mensah", authorize?: false)

      assert length(results) == 1
      assert hd(results).name == "Test User"
    end

    test "search is scoped to store", %{store: store} do
      create_customer!(store, name: "Ama Store1", email: "ama1@example.com")

      other_store = create_store!()
      create_customer!(other_store, name: "Ama Store2", email: "ama2@example.com")

      {:ok, results} = Emakola.Customers.search_customers(store.id, "Ama", authorize?: false)

      assert length(results) == 1
      assert hd(results).name == "Ama Store1"
    end

    test "returns empty list when no match", %{store: store} do
      create_customer!(store, name: "Ama Mensah", email: "ama@example.com")

      {:ok, results} =
        Emakola.Customers.search_customers(store.id, "nonexistent", authorize?: false)

      assert results == []
    end
  end

  # -- get_by_id -------------------------------------------------------------

  describe "get_by_id" do
    test "returns customer by id", %{store: store} do
      customer = create_customer!(store, name: "Ama Mensah", email: "ama@example.com")

      {:ok, found} = Emakola.Customers.get_customer_by_id(customer.id, authorize?: false)

      assert found.id == customer.id
      assert found.name == "Ama Mensah"
    end

    test "returns error for non-existent id" do
      assert {:error, _} =
               Emakola.Customers.get_customer_by_id(Ash.UUID.generate(), authorize?: false)
    end
  end

  # -- order_count aggregate -------------------------------------------------

  describe "order_count aggregate" do
    test "counts orders for a customer", %{store: store} do
      customer = create_customer!(store, name: "Ama Mensah", email: "ama@example.com")

      # Create orders linked to the customer
      create_order!(store, customer_id: customer.id, total: 10_000)
      create_order!(store, customer_id: customer.id, total: 20_000)

      {:ok, loaded} =
        Emakola.Customers.Customer
        |> Ash.Query.filter(id == ^customer.id)
        |> Ash.Query.load(:order_count)
        |> Ash.read_one(authorize?: false)

      assert loaded.order_count == 2
    end

    test "order_count is zero when no orders", %{store: store} do
      customer = create_customer!(store, name: "No Orders", email: "noorders@example.com")

      {:ok, loaded} =
        Emakola.Customers.Customer
        |> Ash.Query.filter(id == ^customer.id)
        |> Ash.Query.load(:order_count)
        |> Ash.read_one(authorize?: false)

      assert loaded.order_count == 0
    end
  end
end
