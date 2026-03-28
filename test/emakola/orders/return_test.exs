defmodule Emakola.Orders.ReturnTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    customer = create_customer!(store, email: "buyer@example.com", name: "Kofi Buyer")
    order = create_order!(store, customer_id: customer.id, status: :delivered)
    {:ok, store: store, customer: customer, order: order}
  end

  # -- Creation -------------------------------------------------------

  describe "request_return" do
    test "creates a return with valid attributes", %{
      store: store,
      customer: customer,
      order: order
    } do
      return = create_return!(store, order, customer)

      assert return.id
      assert return.store_id == store.id
      assert return.order_id == order.id
      assert return.customer_id == customer.id
      assert return.status == :requested
      assert return.reason == :defective
      assert return.currency == "GHS"
    end

    test "creates a return without customer", %{store: store, order: order} do
      return =
        Emakola.Orders.Return
        |> Ash.Changeset.for_create(:request_return, %{
          store_id: store.id,
          order_id: order.id,
          reason: :changed_mind
        })
        |> Ash.create!()

      assert return.id
      assert is_nil(return.customer_id)
      assert return.reason == :changed_mind
    end

    test "creates a return with reason detail", %{
      store: store,
      customer: customer,
      order: order
    } do
      return =
        create_return!(store, order, customer,
          reason: :other,
          reason_detail: "The stitching came undone after one wash"
        )

      assert return.reason_detail == "The stitching came undone after one wash"
    end

    test "defaults status to requested", %{store: store, order: order} do
      return = create_return!(store, order)
      assert return.status == :requested
    end

    test "defaults currency to GHS", %{store: store, order: order} do
      return = create_return!(store, order)
      assert return.currency == "GHS"
    end

    test "enforces one return per order (unique identity)", %{
      store: store,
      customer: customer,
      order: order
    } do
      _first = create_return!(store, order, customer)

      assert {:error, _} =
               Emakola.Orders.Return
               |> Ash.Changeset.for_create(:request_return, %{
                 store_id: store.id,
                 order_id: order.id,
                 customer_id: customer.id,
                 reason: :wrong_item
               })
               |> Ash.create()
    end
  end

  # -- Status transitions ---------------------------------------------

  describe "approve" do
    test "transitions requested to approved", %{store: store, order: order} do
      return = create_return!(store, order)

      approved =
        return
        |> Ash.Changeset.for_update(:approve, %{
          admin_notes: "Approved, items clearly defective",
          refund_amount: 4850
        })
        |> Ash.update!()

      assert approved.status == :approved
      assert approved.admin_notes == "Approved, items clearly defective"
      assert approved.refund_amount == 4850
    end

    test "cannot approve an already approved return", %{store: store, order: order} do
      return = create_return!(store, order)

      approved =
        return
        |> Ash.Changeset.for_update(:approve, %{refund_amount: 4850})
        |> Ash.update!()

      assert {:error, _} =
               approved
               |> Ash.Changeset.for_update(:approve, %{})
               |> Ash.update()
    end

    test "cannot approve a denied return", %{store: store, order: order} do
      return = create_return!(store, order)

      denied =
        return
        |> Ash.Changeset.for_update(:deny, %{admin_notes: "No defect found"})
        |> Ash.update!()

      assert {:error, _} =
               denied
               |> Ash.Changeset.for_update(:approve, %{})
               |> Ash.update()
    end
  end

  describe "deny" do
    test "transitions requested to denied", %{store: store, order: order} do
      return = create_return!(store, order)

      denied =
        return
        |> Ash.Changeset.for_update(:deny, %{admin_notes: "Outside return window"})
        |> Ash.update!()

      assert denied.status == :denied
      assert denied.admin_notes == "Outside return window"
    end

    test "cannot deny a non-requested return", %{store: store, order: order} do
      return = create_return!(store, order)

      approved =
        return
        |> Ash.Changeset.for_update(:approve, %{refund_amount: 4850})
        |> Ash.update!()

      assert {:error, _} =
               approved
               |> Ash.Changeset.for_update(:deny, %{})
               |> Ash.update()
    end
  end

  describe "mark_refunded" do
    test "transitions approved to refunded", %{store: store, order: order} do
      return = create_return!(store, order)

      refunded =
        return
        |> Ash.Changeset.for_update(:approve, %{refund_amount: 4850})
        |> Ash.update!()
        |> Ash.Changeset.for_update(:mark_refunded, %{})
        |> Ash.update!()

      assert refunded.status == :refunded
    end

    test "cannot mark as refunded from requested", %{store: store, order: order} do
      return = create_return!(store, order)

      assert {:error, _} =
               return
               |> Ash.Changeset.for_update(:mark_refunded, %{})
               |> Ash.update()
    end

    test "cannot mark as refunded from denied", %{store: store, order: order} do
      return = create_return!(store, order)

      denied =
        return
        |> Ash.Changeset.for_update(:deny, %{})
        |> Ash.update!()

      assert {:error, _} =
               denied
               |> Ash.Changeset.for_update(:mark_refunded, %{})
               |> Ash.update()
    end
  end

  # -- Read actions ---------------------------------------------------

  describe "list_by_store" do
    test "returns all returns for the given store sorted by inserted_at desc", %{
      store: store,
      order: order
    } do
      _return = create_return!(store, order)

      # Create another order and return for same store
      order2 = create_order!(store, status: :delivered)
      _return2 = create_return!(store, order2, nil, reason: :wrong_item)

      results =
        Emakola.Orders.Return
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!()

      assert length(results) == 2
    end

    test "does not return returns from other stores", %{store: store, order: order} do
      _return = create_return!(store, order)

      other_store = create_store!()
      other_order = create_order!(other_store, status: :delivered)
      _other_return = create_return!(other_store, other_order)

      results =
        Emakola.Orders.Return
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).store_id == store.id
    end
  end

  describe "get_by_order" do
    test "returns the return for a given order", %{store: store, order: order} do
      created = create_return!(store, order)

      results =
        Emakola.Orders.Return
        |> Ash.Query.for_read(:get_by_order, %{order_id: order.id})
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).id == created.id
    end

    test "returns empty list when no return exists for order", %{store: store} do
      order2 = create_order!(store, status: :delivered)

      results =
        Emakola.Orders.Return
        |> Ash.Query.for_read(:get_by_order, %{order_id: order2.id})
        |> Ash.read!()

      assert results == []
    end
  end

  # -- Multi-tenant isolation -----------------------------------------

  describe "multi-tenant isolation" do
    test "returns are isolated by store", %{store: store, order: order} do
      _return = create_return!(store, order)

      other_store = create_store!()
      other_order = create_order!(other_store, status: :delivered)
      _other_return = create_return!(other_store, other_order)

      store_returns =
        Emakola.Orders.Return
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!()

      other_returns =
        Emakola.Orders.Return
        |> Ash.Query.for_read(:list_by_store, %{store_id: other_store.id})
        |> Ash.read!()

      assert length(store_returns) == 1
      assert length(other_returns) == 1
      assert hd(store_returns).store_id == store.id
      assert hd(other_returns).store_id == other_store.id
    end
  end

  # -- Helpers --------------------------------------------------------

  defp create_return!(store, order, customer \\ nil, attrs \\ []) do
    default = %{
      store_id: store.id,
      order_id: order.id,
      reason: :defective
    }

    default =
      if customer do
        Map.put(default, :customer_id, customer.id)
      else
        default
      end

    params = Map.merge(default, Map.new(attrs))

    Emakola.Orders.Return
    |> Ash.Changeset.for_create(:request_return, params)
    |> Ash.create!()
  end
end
