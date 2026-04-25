defmodule EmakolaWeb.Admin.OrderLiveTest do
  @moduledoc """
  LiveView tests for the admin order management pages.
  Tests order listing, filtering, detail view, and status transitions.
  """
  use EmakolaWeb.ConnCase, async: false

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

    test "displays empty state when no orders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/orders")

      assert html =~ "No orders found"
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
        |> element("form[phx-change='search']")
        |> render_change(%{"search" => order.order_number})

      assert html =~ order.order_number
    end

    test "navigates to order detail on row click", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      # Use the order number link specifically (has font-mono class)
      view
      |> element("a.font-mono[href='/admin/orders/#{order.id}']")
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

  describe "OrderLive.Show" do
    test "renders order detail page", %{conn: conn, store: store, customer: customer} do
      order = create_order!(store.id, customer.id, :pending)

      {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

      assert html =~ order.order_number
      assert html =~ "Pending"
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

      assert html =~ "Confirmed"
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

      assert html =~ "Cancelled"
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
      Emakola.Accounts.Store
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store #{System.unique_integer([:positive])}",
        slug: "test-store-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!()

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "merchant-#{System.unique_integer([:positive])}@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!()

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!()

    {merchant, store}
  end

  defp authenticate_conn(conn, merchant) do
    subject = AshAuthentication.user_to_subject(merchant)

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
    |> Ash.create!()
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
      |> Ash.create!()

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
