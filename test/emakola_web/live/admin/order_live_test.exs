defmodule EmakolaWeb.Admin.OrderLiveTest do
  @moduledoc """
  LiveView tests for the admin order management pages.
  Tests order listing, filtering, detail view, and status transitions.
  """
  use EmakolaWeb.ConnCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    # Create merchant, store, and authenticate
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)
    customer = create_customer!(store.id)

    {:ok, conn: conn, store: store, merchant: merchant, customer: customer}
  end

  describe "OrderLive.Index" do
    test "renders order list page", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders")

      assert html =~ "Orders"
      assert html =~ order.order_number
    end

    test "offers a scanner for finding an order from its parcel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      # A merchant holding a parcel should not have to read its order number and
      # type it into search. The button is the visual entry point; the panel
      # only mounts the camera once opened.
      assert has_element?(view, "#scan-order-open")
      refute has_element?(view, "#order-scanner video")

      render_click(view, "open_scanner", %{})
      assert has_element?(view, "#order-scanner video")
    end

    test "a scanned slip navigates to that order", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :processing)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")
      render_click(view, "open_scanner", %{})

      render_hook(view, "qr_scanned", %{"value" => EmakolaWeb.QR.order_tracking_url(store, order)})

      assert_redirect(view, "/admin/orders/#{order.id}")
    end

    test "a scan for another store's order reports not found and stays put", %{conn: conn} do
      other_store = Emakola.Factory.create_store!()
      other_customer = Emakola.Factory.create_customer!(other_store)

      other_order =
        Emakola.Factory.create_order!(other_store, %{
          customer_id: other_customer.id,
          status: :processing
        })

      {:ok, view, _html} = live(conn, ~p"/admin/orders")
      render_click(view, "open_scanner", %{})

      html =
        render_hook(view, "qr_scanned", %{
          "value" => EmakolaWeb.QR.order_tracking_url(other_store, other_order)
        })

      # Tenant isolation, and no hint that the order exists somewhere else.
      assert html =~ "No order here matches that code"
    end

    test "a merchant with no working camera is told, not left staring", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/orders")
      render_click(view, "open_scanner", %{})

      html = render_hook(view, "scan_camera_unavailable", %{})

      assert html =~ "No camera"
    end

    test "a hostile payload never becomes a destination", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/orders")
      render_click(view, "open_scanner", %{})

      html = render_hook(view, "qr_scanned", %{"value" => "https://evil.example/admin/orders"})

      # The decoded string is read as an identifier claim, never followed. A
      # sticker on a parcel cannot steer an authenticated merchant session.
      assert html =~ "No order here matches that code"
    end

    test "displays empty state when no orders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/orders")

      # A store that has never had an order gets first-day guidance rather
      # than "not found" — see the "first day" describe block.
      assert html =~ "Your orders will show here"
    end

    test "caps the order list at 50 rows", %{conn: conn, store: store, customer: customer} do
      for _ <- 1..51, do: create_order!(store.id, customer.id, :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders")

      assert length(String.split(html, ~s(id="order-row-))) - 1 == 50
    end

    test "filters orders by status", %{conn: conn, store: store, customer: customer} do
      pending_order = create_order!(store.id, customer.id, :pending)
      confirmed_order = create_order!(store.id, customer.id, :confirmed)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      # Filter by pending
      html =
        view
        |> element("[phx-click='filter_status'][phx-value-status='pending']")
        |> render_click()

      assert html =~ pending_order.order_number
      refute html =~ confirmed_order.order_number
    end

    test "searches orders by order number", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      html =
        view
        |> element("#order-search-form")
        |> render_change(%{"search" => order.order_number})

      assert html =~ order.order_number
    end

    test "navigates to order detail on row click", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      # The row's name/number block is the link now.
      view
      |> element("#order-row-#{order.id} a[href='/admin/orders/#{order.id}']", order.order_number)
      |> render_click()

      assert_redirect(view, "/admin/orders/#{order.id}")
    end

    test "displays correct status badges", %{conn: conn, store: store, customer: customer} do
      _pending = create_order!(store.id, customer.id, :pending)
      _confirmed = create_order!(store.id, customer.id, :confirmed)

      {:ok, _view, html} = live(conn, ~p"/admin/orders")

      assert html =~ "Pending"
      assert html =~ "Confirmed"
    end

    test "displays formatted prices", %{conn: conn, store: store, customer: customer} do
      _order = create_order!(store.id, customer.id, :pending, total: 52000)

      {:ok, _view, html} = live(conn, ~p"/admin/orders")

      assert html =~ "520"
    end
  end

  describe "OrderLive.Index redesign" do
    test "renders KPI tiles for today, pending, revenue and delivered", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      create_order!(store.id, customer.id, :pending, total: 10_000)
      create_order!(store.id, customer.id, :pending, total: 10_000)
      create_order!(store.id, customer.id, :delivered, total: 30_000)
      create_order!(store.id, customer.id, :cancelled, total: 99_900)

      {:ok, view, html} = live(conn, ~p"/admin/orders")

      assert html =~ "Orders today"
      assert has_element?(view, "#stat-orders-today", "4")
      assert has_element?(view, "#stat-orders-pending", "2")
      # Cancelled money never counts as revenue.
      assert has_element?(view, "#stat-orders-revenue", "GH₵ 500")
      assert has_element?(view, "#stat-orders-delivered", "1")
    end

    test "filter tabs carry store-wide status counts", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      create_order!(store.id, customer.id, :pending)
      create_order!(store.id, customer.id, :pending)
      create_order!(store.id, customer.id, :delivered)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      assert has_element?(view, "#orders-filter-tabs button[phx-value-status=all]", "3")
      assert has_element?(view, "#orders-filter-tabs button[phx-value-status=pending]", "2")
      assert has_element?(view, "#orders-filter-tabs button[phx-value-status=delivered]", "1")
    end

    test "tab counts stay store-wide while the list filters", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      pending = create_order!(store.id, customer.id, :pending)
      delivered = create_order!(store.id, customer.id, :delivered)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      view
      |> element("#orders-filter-tabs button[phx-value-status=pending]")
      |> render_click()

      assert has_element?(view, "#orders-filter-tabs button[phx-value-status=all]", "2")
      assert render(view) =~ pending.order_number
      refute render(view) =~ delivered.order_number
    end
  end

  describe "first day" do
    test "a store with no orders is told how to get one", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/orders")

      assert html =~ "Your orders will show here"
      assert html =~ "Share your store to get the first one"
      # A real WhatsApp share, prefilled with the store's own link — the way
      # these merchants actually send a shop to a customer.
      assert has_element?(view, "a[href^='https://wa.me/?text=']", "Share on WhatsApp")
    end

    test "a filter that matches nothing still says so", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      html =
        view
        |> element("#orders-filter-tabs button[phx-value-status='delivered']")
        |> render_click()

      assert html =~ "No orders found"
      refute html =~ "Your orders will show here"
    end
  end

  describe "OrderLive.Show redesign" do
    test "order journey timeline marks done, current and upcoming steps", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :processing)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#order-timeline [data-step='confirmed'][data-state='done']")
      assert has_element?(view, "#order-timeline [data-step='processing'][data-state='current']")
      assert has_element?(view, "#order-timeline [data-step='shipped'][data-state='todo']")
      assert has_element?(view, "#order-timeline", "Delivered")
    end

    test "a cancelled order shows a cancelled end on the timeline", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :cancelled)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#order-timeline [data-step='cancelled']")
    end

    test "an MTN mobile money payment shows the MTN MoMo rail chip", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :confirmed)

      create_paid_payment!(store, order, %{
        "channel" => "mobile_money",
        "authorization" => %{"channel" => "mobile_money", "bank" => "MTN"}
      })

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#payment-rail-chip", "MTN MoMo")
    end

    test "a card payment shows the card rail chip", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :confirmed)
      create_paid_payment!(store, order, %{"channel" => "card"})

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#payment-rail-chip", "Card")
    end

    test "a hubtel payment without channel data shows the Hubtel chip", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :confirmed)

      Emakola.Factory.create_payment!(store, %{order_id: order.id, gateway: :hubtel})

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#payment-rail-chip", "Hubtel")
    end

    test "line items lead with the product image", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      image = create_line_item_with_image!(store, order)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "img[src='#{image.url}']")
    end
  end

  describe "OrderLive.Show packing slip QR" do
    test "the order carries a QR of its tracking page", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :processing)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      # Printed onto the slip that goes in the parcel: the buyer scans it to
      # track, instead of typing an order number into a URL they were told over
      # the phone. In Phase 2 the same square is what the merchant scans at
      # handoff to jump straight to this order.
      assert has_element?(view, "#order-qr svg")
    end

    test "the packing slip can be printed", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :processing)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#packing-slip-print")
      assert has_element?(view, "#packing-slip", order.order_number)
    end

    test "the QR payload is the store-scoped tracking URL", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :processing)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#packing-slip", EmakolaWeb.QR.order_tracking_url(store, order))
    end
  end

  describe "OrderLive.Show" do
    test "renders order detail page", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ order.order_number
      assert html =~ "pending"
    end

    test "displays customer information", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ customer.name
      assert html =~ to_string(customer.email)
    end

    test "displays order summary with formatted prices", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending, subtotal: 50000, total: 52000)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "500"
      assert html =~ "520"
    end

    test "shows confirm button for pending order", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Confirm Order"
    end

    test "shows start processing button for confirmed order", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :confirmed)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Start Processing"
    end

    test "shows mark shipped button for processing order", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :processing)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Mark as Shipped"
    end

    test "shows mark delivered button for shipped order", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :shipped)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Mark as Delivered"
    end

    test "confirms order via modal confirmation", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      # Push the confirm_order event directly (simulates clicking modal confirm button)
      html = render_click(view, "confirm_order")

      assert html =~ "confirmed"
      assert html =~ "Order confirmed"
    end

    test "starts processing via modal confirmation", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :confirmed)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      html = render_click(view, "start_processing")

      assert html =~ "Processing"
      assert html =~ "Order is now processing"
    end

    test "marks shipped via modal form submission", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :processing)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      html = render_submit(view, "submit_shipped", %{"tracking_number" => "GH123"})

      assert html =~ "Shipped"
    end

    test "marks delivered via modal confirmation", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :shipped)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      html = render_click(view, "mark_delivered")

      assert html =~ "Delivered"
    end

    test "cancels order via modal confirmation", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      html = render_click(view, "cancel_order")

      assert html =~ "cancelled"
      assert html =~ "Order cancelled"
    end

    test "does not show cancel action button for delivered order", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :delivered)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      # The Order Actions section should not contain the cancel trigger button
      # The cancel button has text "Cancel Order" inside the actions area
      # For a delivered order, the :if guard prevents it from rendering
      refute has_element?(view, "div.flex.flex-wrap.gap-3 button", "Cancel Order")
    end

    # A delivered or cancelled order has no next step, so every button in the
    # card was guarded away and the merchant was left looking at a heading over
    # empty space — which reads as a page that failed to load, not as "nothing
    # to do here".
    test "a finished order says so instead of showing an empty actions card", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :delivered)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#order-actions-none", "This order is done")
    end

    test "a cancelled order names its own end state", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :cancelled)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#order-actions-none", "This order was cancelled")
    end

    test "an order with a next step shows buttons, not the finished note", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      refute has_element?(view, "#order-actions-none")
      assert has_element?(view, "div.flex.flex-wrap.gap-3 button", "Confirm Order")
    end

    test "displays shipping address when present", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order =
        create_order!(store.id, customer.id, :pending,
          shipping_address: %{
            "line_1" => "123 Test St",
            "city" => "Accra",
            "region" => "Greater Accra"
          }
        )

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#shipping-address-card", "123 Test St")
      assert has_element?(view, "#shipping-address-card", "Accra")
    end

    test "displays checkout shipping address format", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order =
        create_order!(store.id, customer.id, :pending,
          shipping_address: %{
            "name" => "Ama Mensah",
            "phone" => "+233240000000",
            "address" => "House 14, Osu",
            "region" => "Greater Accra"
          }
        )

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert has_element?(view, "#shipping-address-card", "Ama Mensah")
      assert has_element?(view, "#shipping-address-card", "House 14, Osu")
      assert has_element?(view, "#shipping-address-card", "+233240000000")
    end

    test "renders GhanaPost digital address and landmark with a copy button when present", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order =
        create_order!(store.id, customer.id, :pending,
          shipping_address: %{
            "line_1" => "123 Test St",
            "city" => "Accra",
            "digital_address" => "GA-183-8164",
            "landmark" => "behind Achimota Melcom"
          }
        )

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      card_html = view |> element("#shipping-address-card") |> render()

      assert card_html =~ "GA-183-8164"
      assert card_html =~ "behind Achimota Melcom"
      assert card_html =~ "copy-to-clipboard"
    end

    test "renders legacy shipping address without digital address/landmark unchanged", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order =
        create_order!(store.id, customer.id, :pending,
          shipping_address: %{
            "line_1" => "123 Test St",
            "city" => "Accra",
            "region" => "Greater Accra"
          }
        )

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      card_html = view |> element("#shipping-address-card") |> render()

      refute card_html =~ "copy-to-clipboard"
      refute card_html =~ "Near "
    end
  end

  describe "OrderLive.Show fulfillments" do
    test "renders a supplier fulfillment grouped under the supplier name", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      supplier = Emakola.Factory.create_supplier!(store, name: "Kumasi Supplier")

      Emakola.Factory.create_fulfillment!(order, store,
        supplier_id: supplier.id,
        status: :pending
      )

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Fulfillments"
      assert html =~ "Kumasi Supplier"
      assert html =~ "Send to supplier"
    end

    test "renders the merchant's own-stock fulfillment as 'Your stock'", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      Emakola.Factory.create_fulfillment!(order, store, status: :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Your stock"
    end

    test "sending to supplier enqueues a SupplierNotificationWorker job", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      supplier = Emakola.Factory.create_supplier!(store, name: "Send Supplier")

      fulfillment =
        Emakola.Factory.create_fulfillment!(order, store,
          supplier_id: supplier.id,
          status: :pending
        )

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      html =
        view
        |> element(
          "button[phx-click=\"send_supplier_fulfillment\"][phx-value-id=\"#{fulfillment.id}\"]"
        )
        |> render_click()

      assert html =~ "Sent to supplier"

      assert_enqueued(
        worker: Emakola.Notifications.Workers.SupplierNotificationWorker,
        args: %{"fulfillment_id" => fulfillment.id}
      )
    end

    test "does not dispatch when fulfillment id belongs to another store", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)

      # A second store with its own order, supplier and fulfillment.
      other_store = Emakola.Factory.create_store!()
      other_order = Emakola.Factory.create_order!(other_store)
      other_supplier = Emakola.Factory.create_supplier!(other_store, name: "Foreign Supplier")

      foreign_fulfillment =
        Emakola.Factory.create_fulfillment!(other_order, other_store,
          supplier_id: other_supplier.id,
          status: :pending
        )

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      # Crafted id from another store must be a no-op — no job enqueued, no error.
      render_click(view, "send_supplier_fulfillment", %{"id" => foreign_fulfillment.id})

      refute_enqueued(
        worker: Emakola.Notifications.Workers.SupplierNotificationWorker,
        args: %{"fulfillment_id" => foreign_fulfillment.id}
      )

      assert Process.alive?(view.pid)
    end

    test "marking a fulfillment shipped updates its status", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      supplier = Emakola.Factory.create_supplier!(store, name: "Ship Supplier")

      fulfillment =
        Emakola.Factory.create_fulfillment!(order, store,
          supplier_id: supplier.id,
          status: :pending
        )

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.id}")

      render_click(view, "select_ship_fulfillment", %{"id" => fulfillment.id})
      render_submit(view, "submit_ship_fulfillment", %{"tracking_number" => "GH99"})

      reloaded = Ash.reload!(fulfillment, authorize?: false)
      assert reloaded.status == :shipped
      assert reloaded.tracking_number == "GH99"
    end

    test "displays the order margin", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Margin"
    end
  end

  describe "OrderLive.Show protection hold (TC-2 Task 11)" do
    test "renders no Buyer Protection card when the order has no hold", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      refute html =~ "Buyer Protection"
    end

    test "renders a held hold with status pill, amounts, and no release ETA", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})

      create_protection_hold!(store, payment, %{amount: 25_000, fee: 1_000, net: 24_000})

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Buyer Protection"
      assert html =~ "Held"
      assert html =~ "250"
      assert html =~ "10"
      assert html =~ "240"
    end

    test "renders a frozen hold's status pill (held + an open complaint)", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
      hold = create_protection_hold!(store, payment)

      hold
      |> Ash.Changeset.for_update(:freeze, %{
        complaint_reason: :not_received,
        complaint_text: "Never arrived"
      })
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Frozen"
    end

    test "renders a released hold's status pill and release reason", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
      hold = create_protection_hold!(store, payment)

      hold
      |> Ash.Changeset.for_update(:release, %{release_reason: :buyer_confirmed})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Released"
      assert html =~ "Buyer confirmed"
    end

    test "renders a refunded hold's status pill", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
      hold = create_protection_hold!(store, payment)

      hold
      |> Ash.Changeset.for_update(:mark_refunded, %{resolution: :merchant_refunded})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ "Refunded"
    end

    test "renders the release ETA when set", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = create_order!(store.id, customer.id, :pending)
      payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
      hold = create_protection_hold!(store, payment)
      release_after = DateTime.add(DateTime.utc_now(), 5, :day)

      hold
      |> Ash.Changeset.for_update(:set_release_after, %{release_after: release_after})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ Calendar.strftime(release_after, "%d %b %Y")
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/admin/orders")
    end
  end

  # ── Test Helpers ──

  defp create_authenticated_merchant! do
    store =
      Emakola.Stores.Store
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store #{System.unique_integer([:positive])}",
        slug: "test-store-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!(authorize?: false)

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "merchant-#{System.unique_integer([:positive])}@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!(authorize?: false)
      |> Emakola.Factory.confirm!()

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!(authorize?: false)

    {merchant, store}
  end

  defp authenticate_conn(conn, merchant) do
    subject = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn
    |> init_test_session(%{"user_token" => subject})
  end

  defp create_customer!(store_id) do
    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(:create, %{
      store_id: store_id,
      email: "customer-#{System.unique_integer([:positive])}@test.com",
      name: "Test Customer",
      phone: "+233240000000"
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_order!(store_id, customer_id, status, opts \\ []) do
    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        store_id: store_id,
        customer_id: customer_id,
        subtotal: Keyword.get(opts, :subtotal, 10000),
        total: Keyword.get(opts, :total, 10000),
        currency: "GHS",
        notes: Keyword.get(opts, :notes, nil),
        shipping_address: Keyword.get(opts, :shipping_address, nil),
        billing_address: Keyword.get(opts, :billing_address, nil)
      })
      |> Ash.create!(authorize?: false)

    transition_to_status(order, status)
  end

  defp create_protection_hold!(store, payment, attrs \\ %{}) do
    default = %{
      store_id: store.id,
      payment_id: payment.id,
      order_id: payment.order_id,
      amount: 25_000,
      fee: 1_000,
      net: 24_000
    }

    Emakola.Payments.ProtectionHold
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_paid_payment!(store, order, gateway_response) do
    store
    |> Emakola.Factory.create_payment!(%{order_id: order.id})
    |> Ash.Changeset.for_update(:mark_success, %{gateway_response: gateway_response})
    |> Ash.update!(authorize?: false)
  end

  defp create_line_item_with_image!(store, order) do
    product = Emakola.Factory.create_product!(store, %{title: "Kente Scarf"})
    variant = Emakola.Factory.create_variant!(product, store)
    image = Emakola.Factory.create_image!(product, store)

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    image
  end

  defp transition_to_status(order, :pending), do: order

  defp transition_to_status(order, :confirmed) do
    {:ok, order} = Ash.update(order, %{}, action: :confirm, authorize?: false)
    order
  end

  defp transition_to_status(order, :processing) do
    order = transition_to_status(order, :confirmed)
    {:ok, order} = Ash.update(order, %{}, action: :start_processing, authorize?: false)
    order
  end

  defp transition_to_status(order, :shipped) do
    order = transition_to_status(order, :processing)
    {:ok, order} = Ash.update(order, %{}, action: :mark_shipped, authorize?: false)
    order
  end

  defp transition_to_status(order, :delivered) do
    order = transition_to_status(order, :shipped)
    {:ok, order} = Ash.update(order, %{}, action: :mark_delivered, authorize?: false)
    order
  end

  defp transition_to_status(order, :cancelled) do
    {:ok, order} = Ash.update(order, %{}, action: :cancel, authorize?: false)
    order
  end
end
