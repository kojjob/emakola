defmodule Emakola.Orders.OrderStatusTest do
  @moduledoc """
  Tests for order status transitions.

  Validates the order lifecycle:
  pending -> confirmed -> processing -> shipped -> delivered
  pending|confirmed|processing|shipped -> cancelled
  """
  use Emakola.DataCase, async: true

  alias Emakola.Orders.Order

  require Ash.Query

  setup do
    # Create a store for tenant isolation
    store = create_store!()
    customer = create_customer!(store.id)

    {:ok, store: store, customer: customer}
  end

  describe "confirm action" do
    test "transitions pending order to confirmed", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      assert {:ok, confirmed_order} = Ash.update(order, %{}, action: :confirm)
      assert confirmed_order.status == :confirmed
    end

    test "rejects confirm on non-pending order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :confirmed)

      assert {:error, _} = Ash.update(order, %{}, action: :confirm)
    end

    test "rejects confirm on cancelled order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :cancelled)

      assert {:error, _} = Ash.update(order, %{}, action: :confirm)
    end
  end

  describe "start_processing action" do
    test "transitions confirmed order to processing", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :confirmed)

      assert {:ok, processing_order} = Ash.update(order, %{}, action: :start_processing)
      assert processing_order.status == :processing
    end

    test "rejects start_processing on pending order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      assert {:error, _} = Ash.update(order, %{}, action: :start_processing)
    end

    test "rejects start_processing on shipped order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :shipped)

      assert {:error, _} = Ash.update(order, %{}, action: :start_processing)
    end
  end

  describe "mark_shipped action" do
    test "transitions processing order to shipped", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :processing)

      assert {:ok, shipped_order} = Ash.update(order, %{}, action: :mark_shipped)
      assert shipped_order.status == :shipped
    end

    test "rejects mark_shipped on confirmed order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :confirmed)

      assert {:error, _} = Ash.update(order, %{}, action: :mark_shipped)
    end

    test "rejects mark_shipped on pending order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      assert {:error, _} = Ash.update(order, %{}, action: :mark_shipped)
    end
  end

  describe "mark_delivered action" do
    test "transitions shipped order to delivered", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :shipped)

      assert {:ok, delivered_order} = Ash.update(order, %{}, action: :mark_delivered)
      assert delivered_order.status == :delivered
    end

    test "rejects mark_delivered on processing order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :processing)

      assert {:error, _} = Ash.update(order, %{}, action: :mark_delivered)
    end

    test "rejects mark_delivered on pending order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      assert {:error, _} = Ash.update(order, %{}, action: :mark_delivered)
    end
  end

  describe "cancel action" do
    test "cancels a pending order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      assert {:ok, cancelled_order} = Ash.update(order, %{}, action: :cancel)
      assert cancelled_order.status == :cancelled
    end

    test "cancels a confirmed order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :confirmed)

      assert {:ok, cancelled_order} = Ash.update(order, %{}, action: :cancel)
      assert cancelled_order.status == :cancelled
    end

    test "cancels a processing order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :processing)

      assert {:ok, cancelled_order} = Ash.update(order, %{}, action: :cancel)
      assert cancelled_order.status == :cancelled
    end

    test "cancels a shipped order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :shipped)

      assert {:ok, cancelled_order} = Ash.update(order, %{}, action: :cancel)
      assert cancelled_order.status == :cancelled
    end

    test "rejects cancel on delivered order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :delivered)

      assert {:error, _} = Ash.update(order, %{}, action: :cancel)
    end

    test "rejects cancel on already cancelled order", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :cancelled)

      assert {:error, _} = Ash.update(order, %{}, action: :cancel)
    end
  end

  describe "full lifecycle" do
    test "pending -> confirmed -> processing -> shipped -> delivered", %{
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      assert order.status == :pending

      {:ok, order} = Ash.update(order, %{}, action: :confirm)
      assert order.status == :confirmed

      {:ok, order} = Ash.update(order, %{}, action: :start_processing)
      assert order.status == :processing

      {:ok, order} = Ash.update(order, %{}, action: :mark_shipped)
      assert order.status == :shipped

      {:ok, order} = Ash.update(order, %{}, action: :mark_delivered)
      assert order.status == :delivered
    end

    test "cannot skip states (pending -> shipped)", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      assert {:error, _} = Ash.update(order, %{}, action: :mark_shipped)
    end

    test "cannot reverse states (delivered -> confirmed)", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :delivered)

      assert {:error, _} = Ash.update(order, %{}, action: :confirm)
    end
  end

  describe "get_by_id action" do
    test "loads order with line items", %{store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      assert {:ok, [found_order]} =
               Order
               |> Ash.Query.filter(id: order.id)
               |> Ash.Query.load(:line_items)
               |> Ash.read(action: :read)

      assert found_order.id == order.id
      assert found_order.line_items == []
    end
  end

  # ── Test Helpers ──

  defp create_store! do
    Emakola.Accounts.Store
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Store #{System.unique_integer([:positive])}",
      slug: "test-store-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!()
  end

  defp create_customer!(store_id) do
    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(:create, %{
      store_id: store_id,
      email: "customer-#{System.unique_integer([:positive])}@test.com",
      name: "Test Customer"
    })
    |> Ash.create!()
  end

  defp create_order!(store_id, customer_id, status) do
    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        store_id: store_id,
        customer_id: customer_id,
        subtotal: 10000,
        total: 10000,
        currency: "GHS"
      })
      |> Ash.create!()

    # Transition to the desired status through the valid path
    transition_to_status(order, status)
  end

  defp transition_to_status(order, :pending), do: order

  defp transition_to_status(order, :confirmed) do
    {:ok, order} = Ash.update(order, %{}, action: :confirm)
    order
  end

  defp transition_to_status(order, :processing) do
    order = transition_to_status(order, :confirmed)
    {:ok, order} = Ash.update(order, %{}, action: :start_processing)
    order
  end

  defp transition_to_status(order, :shipped) do
    order = transition_to_status(order, :processing)
    {:ok, order} = Ash.update(order, %{}, action: :mark_shipped)
    order
  end

  defp transition_to_status(order, :delivered) do
    order = transition_to_status(order, :shipped)
    {:ok, order} = Ash.update(order, %{}, action: :mark_delivered)
    order
  end

  defp transition_to_status(order, :cancelled) do
    {:ok, order} = Ash.update(order, %{}, action: :cancel)
    order
  end
end
