defmodule Emakola.Orders.FulfillmentSupplierActionTest do
  @moduledoc """
  The supplier-facing half of the fulfillment state machine.

  Two asymmetries are deliberate and are what these tests pin down:

    * **Accept is a timestamp, decline is a status.** A supplier saying "I have
      it" is informational — nothing queries or filters on it — so it sets
      `accepted_at` and leaves `status` alone. A supplier saying "no stock" is
      a blocked order the merchant must act on, so it gets its own `:declined`
      status. Reusing `:cancelled` for a decline would drop the fulfillment out
      of the merchant's action row entirely.

    * **`:declined` is not terminal for the merchant.** They can still ship it
      (having sourced the item elsewhere) or cancel it. Only the *supplier's*
      view treats it as done.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Orders.Fulfillment

  setup do
    store = create_store!()
    order = create_order!(store)
    supplier = create_supplier!(store)
    %{store: store, order: order, supplier: supplier}
  end

  defp fulfillment(ctx, attrs \\ %{}) do
    create_fulfillment!(ctx.order, ctx.store, Map.merge(%{supplier_id: ctx.supplier.id}, attrs))
  end

  defp reload(f), do: Ash.get!(Fulfillment, f.id, authorize?: false)

  describe "supplier_accept" do
    test "stamps accepted_at from :pending without moving status", ctx do
      f = fulfillment(ctx)

      assert {:ok, accepted} = Emakola.Orders.supplier_accept_fulfillment(f, authorize?: false)

      assert accepted.status == :pending, "accept must not move status"
      assert %DateTime{} = accepted.accepted_at
    end

    test "stamps accepted_at from :notified without moving status", ctx do
      f = fulfillment(ctx)

      {:ok, f} =
        Emakola.Orders.mark_fulfillment_notified(f, %{notified_via: :sms}, authorize?: false)

      assert {:ok, accepted} = Emakola.Orders.supplier_accept_fulfillment(f, authorize?: false)

      assert accepted.status == :notified
      assert %DateTime{} = accepted.accepted_at
    end

    test "is idempotent — a second accept does not slide the timestamp", ctx do
      f = fulfillment(ctx)
      {:ok, first} = Emakola.Orders.supplier_accept_fulfillment(f, authorize?: false)

      {:ok, second} = Emakola.Orders.supplier_accept_fulfillment(first, authorize?: false)

      assert second.accepted_at == first.accepted_at
    end

    test "is rejected once the fulfillment has shipped", ctx do
      f = fulfillment(ctx)

      {:ok, shipped} =
        Emakola.Orders.mark_fulfillment_shipped(f, %{tracking_number: "GH-1"}, authorize?: false)

      assert {:error, _} = Emakola.Orders.supplier_accept_fulfillment(shipped, authorize?: false)
      assert is_nil(reload(f).accepted_at)
    end

    test "is rejected once the fulfillment is cancelled", ctx do
      f = fulfillment(ctx)
      {:ok, cancelled} = Emakola.Orders.cancel_fulfillment(f, authorize?: false)

      assert {:error, _} =
               Emakola.Orders.supplier_accept_fulfillment(cancelled, authorize?: false)
    end
  end

  describe "supplier_decline" do
    test "moves to :declined and stamps declined_at plus the reason", ctx do
      f = fulfillment(ctx)

      assert {:ok, declined} =
               Emakola.Orders.supplier_decline_fulfillment(
                 f,
                 %{decline_reason: :out_of_stock},
                 authorize?: false
               )

      assert declined.status == :declined
      assert %DateTime{} = declined.declined_at
      assert declined.decline_reason == :out_of_stock
    end

    test "is allowed after an accept — the shelf can be empty by noon", ctx do
      f = fulfillment(ctx)
      {:ok, accepted} = Emakola.Orders.supplier_accept_fulfillment(f, authorize?: false)

      assert {:ok, declined} =
               Emakola.Orders.supplier_decline_fulfillment(
                 accepted,
                 %{decline_reason: :out_of_stock},
                 authorize?: false
               )

      assert declined.status == :declined
      refute is_nil(declined.accepted_at), "the earlier acceptance is history, not erased"
    end

    test "is rejected once the fulfillment has shipped", ctx do
      f = fulfillment(ctx)

      {:ok, shipped} =
        Emakola.Orders.mark_fulfillment_shipped(f, %{tracking_number: "GH-1"}, authorize?: false)

      assert {:error, _} =
               Emakola.Orders.supplier_decline_fulfillment(
                 shipped,
                 %{decline_reason: :out_of_stock},
                 authorize?: false
               )

      assert reload(f).status == :shipped
    end
  end

  describe "the merchant's recovery from a decline" do
    setup ctx do
      f = fulfillment(ctx)

      {:ok, declined} =
        Emakola.Orders.supplier_decline_fulfillment(
          f,
          %{decline_reason: :out_of_stock},
          authorize?: false
        )

      Map.put(ctx, :declined, declined)
    end

    test "mark_shipped works from :declined — the merchant sourced it elsewhere", %{
      declined: declined
    } do
      assert {:ok, shipped} =
               Emakola.Orders.mark_fulfillment_shipped(
                 declined,
                 %{tracking_number: "GH-ELSEWHERE-9"},
                 authorize?: false
               )

      assert shipped.status == :shipped
      assert shipped.tracking_number == "GH-ELSEWHERE-9"
    end

    test "cancel works from :declined — refund reconciliation depends on it", %{
      declined: declined
    } do
      assert {:ok, cancelled} = Emakola.Orders.cancel_fulfillment(declined, authorize?: false)
      assert cancelled.status == :cancelled
    end
  end

  describe "rotate_supplier_link" do
    test "starts at 1 and increments, revoking every token minted before", ctx do
      f = fulfillment(ctx)
      assert f.supplier_link_version == 1

      assert {:ok, rotated} =
               Emakola.Orders.rotate_fulfillment_supplier_link(f, authorize?: false)

      assert rotated.supplier_link_version == 2
    end

    test "works from any status — a link may be revoked at any time", ctx do
      f = fulfillment(ctx)

      {:ok, shipped} =
        Emakola.Orders.mark_fulfillment_shipped(f, %{tracking_number: "GH-1"}, authorize?: false)

      assert {:ok, rotated} =
               Emakola.Orders.rotate_fulfillment_supplier_link(shipped, authorize?: false)

      assert rotated.supplier_link_version == 2
    end
  end

  describe "stale callers (RequireStatusIn pushes the predicate into the WHERE)" do
    test "a stale struct cannot accept a fulfillment the merchant just cancelled", ctx do
      f = fulfillment(ctx)
      {:ok, _} = Emakola.Orders.cancel_fulfillment(f, authorize?: false)

      # `f` is the handle the supplier's open browser tab is still holding.
      assert {:error, error} = Emakola.Orders.supplier_accept_fulfillment(f, authorize?: false)

      reloaded = reload(f)

      assert reloaded.status == :cancelled,
             "a cancelled fulfillment was accepted by a stale caller: #{inspect(error)}"

      assert is_nil(reloaded.accepted_at)
    end

    test "a stale struct cannot decline a fulfillment that already shipped", ctx do
      f = fulfillment(ctx)

      {:ok, _} =
        Emakola.Orders.mark_fulfillment_shipped(f, %{tracking_number: "GH-1"}, authorize?: false)

      assert {:error, error} =
               Emakola.Orders.supplier_decline_fulfillment(
                 f,
                 %{decline_reason: :out_of_stock},
                 authorize?: false
               )

      assert reload(f).status == :shipped,
             "a shipped fulfillment was declined by a stale caller: #{inspect(error)}"
    end
  end
end
