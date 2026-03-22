defmodule Emakola.Orders.OrderTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    customer = create_customer!(store, email: "buyer@example.com", name: "Kofi Buyer")
    {:ok, store: store, customer: customer}
  end

  # -- Creation -------------------------------------------------------

  describe "create" do
    test "creates an order with valid attributes", %{store: store, customer: customer} do
      order = create_order!(store, customer_id: customer.id)

      assert order.id
      assert order.store_id == store.id
      assert order.customer_id == customer.id
      assert order.status == :pending
      assert order.subtotal == 0
      assert order.total == 0
      assert order.currency == "GHS"
    end

    test "auto-generates order_number in correct format", %{store: store} do
      order = create_order!(store)

      assert order.order_number
      assert Regex.match?(~r/^ORD-\d{8}-[A-Z0-9]{6}$/, order.order_number)
    end

    test "creates order without customer (anonymous checkout)", %{store: store} do
      order = create_order!(store)

      assert order.id
      assert is_nil(order.customer_id)
    end

    test "creates order with shipping and billing addresses", %{store: store} do
      address = %{"street" => "123 Main St", "city" => "Accra", "region" => "Greater Accra"}

      order = create_order!(store, shipping_address: address, billing_address: address)

      assert order.shipping_address == address
      assert order.billing_address == address
    end

    test "creates order with notes", %{store: store} do
      order = create_order!(store, notes: "Please deliver before noon")
      assert order.notes == "Please deliver before noon"
    end

    test "order_number is unique per store", %{store: store} do
      order1 = create_order!(store)
      order2 = create_order!(store)

      assert order1.order_number != order2.order_number
    end
  end

  # -- Status transitions ---------------------------------------------

  describe "status transitions" do
    test "confirm transitions pending to confirmed", %{store: store} do
      order = create_order!(store)
      assert order.status == :pending

      confirmed =
        order
        |> Ash.Changeset.for_update(:confirm, %{})
        |> Ash.update!()

      assert confirmed.status == :confirmed
    end

    test "cancel transitions pending to cancelled", %{store: store} do
      order = create_order!(store)

      cancelled =
        order
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update!()

      assert cancelled.status == :cancelled
    end

    test "cannot confirm a cancelled order", %{store: store} do
      order = create_order!(store)

      cancelled =
        order
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update!()

      assert {:error, _} =
               cancelled
               |> Ash.Changeset.for_update(:confirm, %{})
               |> Ash.update()
    end
  end

  # -- Read actions ---------------------------------------------------

  describe "list_by_store" do
    test "returns orders for the given store sorted by inserted_at desc", %{store: store} do
      order1 = create_order!(store)
      order2 = create_order!(store)

      results =
        Emakola.Orders.Order
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!()

      ids = Enum.map(results, & &1.id)
      assert order2.id in ids
      assert order1.id in ids
      # Most recent first
      assert hd(ids) == order2.id
    end

    test "does not return orders from other stores", %{store: store} do
      other_store = create_store!()
      _own_order = create_order!(store)
      _other_order = create_order!(other_store)

      results =
        Emakola.Orders.Order
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).store_id == store.id
    end
  end

  describe "list_by_status" do
    test "filters orders by store and status", %{store: store} do
      order1 = create_order!(store)

      order2 =
        create_order!(store)
        |> Ash.Changeset.for_update(:confirm, %{})
        |> Ash.update!()

      pending_results =
        Emakola.Orders.Order
        |> Ash.Query.for_read(:list_by_status, %{store_id: store.id, status: :pending})
        |> Ash.read!()

      confirmed_results =
        Emakola.Orders.Order
        |> Ash.Query.for_read(:list_by_status, %{store_id: store.id, status: :confirmed})
        |> Ash.read!()

      assert length(pending_results) == 1
      assert hd(pending_results).id == order1.id
      assert length(confirmed_results) == 1
      assert hd(confirmed_results).id == order2.id
    end
  end

  # -- Multi-tenant isolation -----------------------------------------

  describe "multi-tenant isolation" do
    test "orders are isolated by store", %{store: store} do
      other_store = create_store!()
      create_order!(store)
      create_order!(store)
      create_order!(other_store)

      store_orders =
        Emakola.Orders.Order
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!()

      other_orders =
        Emakola.Orders.Order
        |> Ash.Query.for_read(:list_by_store, %{store_id: other_store.id})
        |> Ash.read!()

      assert length(store_orders) == 2
      assert length(other_orders) == 1
    end
  end
end
