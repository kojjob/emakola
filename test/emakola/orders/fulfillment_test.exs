defmodule Emakola.Orders.FulfillmentTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    order = create_order!(store)
    supplier = create_supplier!(store)
    {:ok, store: store, order: order, supplier: supplier}
  end

  describe "create" do
    test "creates with valid attrs and defaults status to :pending", %{
      store: store,
      order: order,
      supplier: supplier
    } do
      fulfillment =
        Emakola.Orders.Fulfillment
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          order_id: order.id,
          supplier_id: supplier.id
        })
        |> Ash.create!(authorize?: false)

      assert fulfillment.status == :pending
      assert fulfillment.supplier_id == supplier.id
      assert fulfillment.store_id == store.id
      assert fulfillment.order_id == order.id
    end

    test "allows a nil supplier_id (merchant-owned group)", %{store: store, order: order} do
      fulfillment = create_fulfillment!(order, store)
      assert is_nil(fulfillment.supplier_id)
      assert fulfillment.status == :pending
    end

    test "is scoped to its store", %{store: store, order: order, supplier: supplier} do
      fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

      other_store = create_store!()

      results =
        Emakola.Orders.Fulfillment
        |> Ash.Query.set_tenant(other_store.id)
        |> Ash.read!(authorize?: false)

      refute Enum.any?(results, &(&1.id == fulfillment.id))
    end
  end

  describe "status transitions" do
    test "mark_notified sets status, notified_at, and notified_via", %{
      store: store,
      order: order,
      supplier: supplier
    } do
      fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

      updated =
        fulfillment
        |> Ash.Changeset.for_update(:mark_notified, %{notified_via: :whatsapp})
        |> Ash.update!(authorize?: false)

      assert updated.status == :notified
      assert updated.notified_via == :whatsapp
      assert %DateTime{} = updated.notified_at
    end

    test "mark_notified rejects a non-pending fulfillment", %{
      store: store,
      order: order,
      supplier: supplier
    } do
      fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

      shipped =
        fulfillment
        |> Ash.Changeset.for_update(:mark_shipped, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, _} =
               shipped
               |> Ash.Changeset.for_update(:mark_notified, %{notified_via: :sms})
               |> Ash.update(authorize?: false)
    end

    test "mark_shipped from pending and notified, with tracking number", %{
      store: store,
      order: order
    } do
      f1 = create_fulfillment!(order, store)

      shipped =
        f1
        |> Ash.Changeset.for_update(:mark_shipped, %{tracking_number: "TRK-123"})
        |> Ash.update!(authorize?: false)

      assert shipped.status == :shipped
      assert shipped.tracking_number == "TRK-123"

      f2 = create_fulfillment!(order, store)

      notified =
        f2
        |> Ash.Changeset.for_update(:mark_notified, %{notified_via: :manual})
        |> Ash.update!(authorize?: false)

      shipped2 =
        notified
        |> Ash.Changeset.for_update(:mark_shipped, %{})
        |> Ash.update!(authorize?: false)

      assert shipped2.status == :shipped
    end

    test "mark_delivered only from shipped", %{store: store, order: order} do
      fulfillment = create_fulfillment!(order, store)

      assert {:error, _} =
               fulfillment
               |> Ash.Changeset.for_update(:mark_delivered, %{})
               |> Ash.update(authorize?: false)

      delivered =
        fulfillment
        |> Ash.Changeset.for_update(:mark_shipped, %{})
        |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:mark_delivered, %{})
        |> Ash.update!(authorize?: false)

      assert delivered.status == :delivered
    end

    test "cancel from active states, rejected from delivered", %{store: store, order: order} do
      fulfillment = create_fulfillment!(order, store)

      cancelled =
        fulfillment
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update!(authorize?: false)

      assert cancelled.status == :cancelled

      delivered =
        create_fulfillment!(order, store)
        |> Ash.Changeset.for_update(:mark_shipped, %{})
        |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:mark_delivered, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, _} =
               delivered
               |> Ash.Changeset.for_update(:cancel, %{})
               |> Ash.update(authorize?: false)
    end

    test "cancel rejects an already-cancelled fulfillment", %{store: store, order: order} do
      cancelled =
        create_fulfillment!(order, store)
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, _} =
               cancelled
               |> Ash.Changeset.for_update(:cancel, %{})
               |> Ash.update(authorize?: false)
    end

    test "mark_notified rejects a delivered fulfillment", %{store: store, order: order} do
      delivered =
        create_fulfillment!(order, store)
        |> Ash.Changeset.for_update(:mark_shipped, %{})
        |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:mark_delivered, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, _} =
               delivered
               |> Ash.Changeset.for_update(:mark_notified, %{notified_via: :sms})
               |> Ash.update(authorize?: false)
    end

    test "mark_notified rejects a cancelled fulfillment", %{store: store, order: order} do
      cancelled =
        create_fulfillment!(order, store)
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, _} =
               cancelled
               |> Ash.Changeset.for_update(:mark_notified, %{notified_via: :sms})
               |> Ash.update(authorize?: false)
    end
  end

  describe "list_by_order" do
    test "returns fulfillments for an order sorted by inserted_at asc", %{
      store: store,
      order: order,
      supplier: supplier
    } do
      f1 = create_fulfillment!(order, store, supplier_id: supplier.id)
      f2 = create_fulfillment!(order, store)

      results = Emakola.Orders.list_fulfillments_by_order!(order.id, authorize?: false)

      assert Enum.map(results, & &1.id) == [f1.id, f2.id]
    end
  end
end
