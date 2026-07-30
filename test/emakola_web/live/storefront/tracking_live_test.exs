defmodule EmakolaWeb.Storefront.TrackingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Payments
  alias Emakola.Payments.ProtectionHolds
  alias EmakolaWeb.TrackingTokens

  setup do
    store = create_store!(%{name: "Ghana Shop", slug: "ghana-shop", currency: "GHS"})
    product = create_product!(store, %{title: "Kente Wrap Dress"})

    variant =
      create_variant!(product, store, %{price: 28_000, stock_quantity: 10, sku: "KWD-001"})

    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        notes: "Test tracking order",
        shipping_address: %{
          "name" => "Ama Mensah",
          "phone" => "+233241234567",
          "address" => "House 14, Osu",
          "region" => "greater_accra"
        }
      )

    %{store: store, order: order, product: product, variant: variant}
  end

  describe "TrackingLive with real order" do
    test "renders tracking page with order number", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ order.order_number
      assert html =~ store.name
    end

    test "shows delivery status timeline", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Delivery Status"
      assert html =~ "Order Placed"
      assert html =~ "Confirmed"
      assert html =~ "Being Prepared"
      assert html =~ "Shipped"
      assert html =~ "Delivered"
    end

    test "shows status hero for pending order", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Awaiting Confirmation"
      assert html =~ "Waiting for payment confirmation"
    end

    test "shows order details section with real items", %{conn: conn, store: store, order: order} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert render(view) =~ "Order Details"

      html = render_click(view, "toggle_details")

      assert html =~ "Kente Wrap Dress"
      assert html =~ "GH\u20B5"
    end

    test "shows total in order details", %{conn: conn, store: store, order: order} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      html = render_click(view, "toggle_details")

      assert html =~ "Total"
      assert html =~ "Subtotal"
    end

    test "shows shipping address in order details", %{conn: conn, store: store, order: order} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      html = render_click(view, "toggle_details")

      assert html =~ "Ama Mensah"
      assert html =~ "House 14, Osu"
    end

    test "toggle order details expands/collapses", %{conn: conn, store: store, order: order} do
      {:ok, view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      refute html =~ "Kente Wrap Dress"

      html = render_click(view, "toggle_details")
      assert html =~ "Kente Wrap Dress"

      html = render_click(view, "toggle_details")
      refute html =~ "Kente Wrap Dress"
    end

    test "does not show rider card for non-shipped order", %{
      conn: conn,
      store: store,
      order: order
    } do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      refute html =~ "Contact Store"
    end

    test "shows confirmed status hero for confirmed order", %{
      conn: conn,
      store: store,
      order: order
    } do
      Emakola.Orders.confirm_order!(order, authorize?: false)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Order Confirmed"
      assert html =~ "Your payment has been verified"
    end

    test "shows processing status for processing order", %{conn: conn, store: store, order: order} do
      order = Emakola.Orders.confirm_order!(order, authorize?: false)
      Emakola.Orders.start_processing_order!(order, authorize?: false)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Being Prepared"
      assert html =~ "The seller is preparing your order"
    end

    test "shows rider card for shipped order", %{conn: conn, store: store, order: order} do
      order = Emakola.Orders.confirm_order!(order, authorize?: false)
      order = Emakola.Orders.start_processing_order!(order, authorize?: false)
      Emakola.Orders.mark_order_shipped!(order, authorize?: false)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Order Shipped"
      assert html =~ "Contact Store"
    end

    test "shows delivered status for delivered order", %{conn: conn, store: store, order: order} do
      order = Emakola.Orders.confirm_order!(order, authorize?: false)
      order = Emakola.Orders.start_processing_order!(order, authorize?: false)
      order = Emakola.Orders.mark_order_shipped!(order, authorize?: false)
      Emakola.Orders.mark_order_delivered!(order, authorize?: false)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Delivered"
      assert html =~ "Your order has been delivered"
    end
  end

  describe "error handling" do
    test "redirects for non-existent order", %{conn: conn, store: store} do
      assert {:error, {:redirect, %{to: "/s/ghana-shop"}}} =
               live(conn, "/s/#{store.slug}/track/ORD-INVALID-000000")
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store/track/EM-4821")
    end
  end

  # TC-2 buyer protection: the merchant also knows the order number, so a
  # bare tracking URL must never move money — buyer actions require a
  # signed token bound to THIS order. `protected_order!/2` mirrors
  # `ProtectionReleaseTest`'s `protected_payment!/2` fixture, but builds an
  # order with a real `order_number` (required to hit the tracking route).
  describe "buyer protection" do
    defp protected_order!(store, attrs \\ %{}) do
      attrs = Map.new(attrs)
      amount = Map.get(attrs, :amount, 25_000)
      order = create_order!(store, %{total: amount})

      payment =
        store
        |> create_payment!(
          Map.merge(
            %{
              order_id: order.id,
              amount: amount,
              payout_held: true,
              payout_hold_reason: "buyer_protection"
            },
            attrs
          )
        )
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update!(authorize?: false)

      :ok = ProtectionHolds.ensure_hold(payment)

      {:ok, hold} =
        Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

      {order, hold}
    end

    defp reload_hold(store, hold) do
      {:ok, reloaded} =
        Payments.get_protection_hold_by_payment(hold.payment_id,
          tenant: store.id,
          authorize?: false
        )

      reloaded
    end

    test "no protection strip when the order has no protection hold", %{
      conn: conn,
      store: store,
      order: order
    } do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      refute html =~ "Buyer Protection"
    end

    test "renders the protection strip for any viewer but hides buyer controls without a token",
         %{conn: conn, store: store} do
      {order, _hold} = protected_order!(store)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Buyer Protection"
      assert html =~ "Payment held"
      refute html =~ "I received my order"
      refute html =~ "Report a problem"
    end

    test "shows buyer controls when the tracking link carries a valid signed token", %{
      conn: conn,
      store: store
    } do
      {order, _hold} = protected_order!(store)
      token = TrackingTokens.sign_order_tracking(order.id)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}?t=#{token}")

      assert html =~ "I received my order"
      assert html =~ "Report a problem"
    end

    test "a token signed for a different order does not authorize buyer controls (threat test)",
         %{conn: conn, store: store} do
      {order, _hold} = protected_order!(store)
      {other_order, _other_hold} = protected_order!(store)
      token = TrackingTokens.sign_order_tracking(other_order.id)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}?t=#{token}")

      refute html =~ "I received my order"
      refute html =~ "Report a problem"
    end

    test "pushing confirm_received directly on an unauthorized socket does not release the hold (threat test)",
         %{conn: conn, store: store} do
      {order, hold} = protected_order!(store)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      render_click(view, "confirm_received")

      reloaded = reload_hold(store, hold)
      assert reloaded.status == :held
      assert is_nil(reloaded.released_at)
      assert is_nil(reloaded.release_reason)
    end

    test "authorized confirm_received releases the hold as buyer_confirmed", %{
      conn: conn,
      store: store
    } do
      {order, hold} = protected_order!(store)
      token = TrackingTokens.sign_order_tracking(order.id)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}?t=#{token}")

      html = render_click(view, "confirm_received")

      assert html =~ "Thanks for confirming"

      reloaded = reload_hold(store, hold)
      assert reloaded.status == :released
      assert reloaded.release_reason == :buyer_confirmed
    end

    test "confirming a frozen hold stays held and surfaces the complaint-under-review outcome",
         %{conn: conn, store: store} do
      {order, hold} = protected_order!(store)

      {:ok, _frozen} =
        Payments.freeze_protection_hold(
          hold,
          %{complaint_reason: :not_received, complaint_text: "never showed up"},
          authorize?: false
        )

      token = TrackingTokens.sign_order_tracking(order.id)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}?t=#{token}")

      html = render_click(view, "confirm_received")

      assert html =~ "complaint is under review"

      reloaded = reload_hold(store, hold)
      assert reloaded.status == :held
      assert reloaded.frozen_at
    end

    test "authorized file_complaint freezes the hold with reason and text", %{
      conn: conn,
      store: store
    } do
      {order, hold} = protected_order!(store)
      token = TrackingTokens.sign_order_tracking(order.id)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}?t=#{token}")

      html =
        render_submit(view, "file_complaint", %{
          "reason" => "not_as_described",
          "text" => "wrong color"
        })

      assert html =~ "Complaint received"

      reloaded = reload_hold(store, hold)
      assert reloaded.frozen_at
      assert reloaded.complaint_reason == :not_as_described
      assert reloaded.complaint_text == "wrong color"
      assert reloaded.status == :held
    end

    test "pushing file_complaint directly on an unauthorized socket does not freeze the hold (threat test)",
         %{conn: conn, store: store} do
      {order, hold} = protected_order!(store)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      render_submit(view, "file_complaint", %{"reason" => "other", "text" => "nope"})

      reloaded = reload_hold(store, hold)
      refute reloaded.frozen_at
    end

    test "filing a second complaint updates the existing complaint instead of erroring", %{
      conn: conn,
      store: store
    } do
      {order, hold} = protected_order!(store)
      token = TrackingTokens.sign_order_tracking(order.id)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}?t=#{token}")

      render_submit(view, "file_complaint", %{
        "reason" => "not_as_described",
        "text" => "wrong color"
      })

      first_filing = reload_hold(store, hold)

      html =
        render_submit(view, "file_complaint", %{
          "reason" => "not_received",
          "text" => "actually never arrived"
        })

      refute html =~ "Could not file your complaint"

      reloaded = reload_hold(store, hold)
      # Same complaint row — `frozen_at` is not reset by the re-file.
      assert reloaded.id == hold.id
      assert reloaded.frozen_at == first_filing.frozen_at
      assert reloaded.complaint_reason == :not_received
      assert reloaded.complaint_text == "actually never arrived"
      assert reloaded.status == :held
    end

    test "open_complaint is a no-op without a valid token", %{conn: conn, store: store} do
      {order, _hold} = protected_order!(store)

      {:ok, view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      refute html =~ "What went wrong?"

      html = render_click(view, "open_complaint")

      refute html =~ "What went wrong?"
    end
  end
end
