defmodule EmakolaWeb.Admin.ReturnLiveTest do
  @moduledoc """
  LiveView tests for the admin return management page.
  Tests return listing, filtering, approve/deny actions, and empty state.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias EmakolaWeb.Helpers.Currency

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "ReturnLive" do
    test "renders returns page with title and subtitle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/returns")

      assert html =~ "Returns"
      assert html =~ "Review and manage customer return requests"
    end

    test "displays empty state when no returns exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/returns")

      assert html =~ "No returns found"
      assert html =~ "Return requests from customers will appear here"
    end

    test "displays status filter tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/returns")

      assert html =~ "All"
      assert html =~ "Requested"
      assert html =~ "Approved"
      assert html =~ "Denied"
      assert html =~ "Refunded"
    end

    test "lists returns for the store", %{conn: conn, store: store} do
      return = create_return!(store)

      {:ok, _view, html} = live(conn, ~p"/admin/returns")

      assert html =~ String.slice(return.order_id, 0..7)
      assert html =~ "Requested"
    end

    test "filters returns by status", %{conn: conn, store: store} do
      _requested = create_return!(store)

      order2 = create_order!(store, :delivered)
      approved = create_approved_return!(store, order2)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      html =
        view
        |> element("[phx-click='filter_status'][phx-value-status='approved']")
        |> render_click()

      assert html =~ String.slice(approved.order_id, 0..7)
    end

    test "shows return detail when clicked", %{conn: conn, store: store} do
      return = create_return!(store, nil, reason: :wrong_item)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      html = render_click(view, "select_return", %{"id" => return.id})

      assert html =~ "Return Details"
      assert html =~ "Wrong item received"
    end

    test "approve button appears for requested returns", %{conn: conn, store: store} do
      return = create_return!(store)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      html = render_click(view, "select_return", %{"id" => return.id})

      assert html =~ "Approve"
      assert html =~ "Deny"
    end

    test "every phx-change element in the approve panel has a form ancestor", %{
      conn: conn,
      store: store
    } do
      # Structural guard, not a behavior test: render_change/render_click invoke
      # handle_event/3 directly and bypass the browser entirely, so no amount of
      # passing behavior tests proves these bindings actually work in a real
      # browser. A phx-change on an <input>/<textarea> with no <form> ancestor
      # makes LiveView's JS client throw "form events require the input to be
      # inside a form" on every keystroke — silently, since nothing in the
      # Elixir test suite executes that JS. We assert the DOM shape instead.
      return = create_return!(store)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      html = render_click(view, "select_return", %{"id" => return.id})

      doc = LazyHTML.from_document(html)

      all_phx_change = doc |> LazyHTML.query("[phx-change]") |> Enum.count()
      inside_form = doc |> LazyHTML.query("form [phx-change]") |> Enum.count()

      assert all_phx_change > 0, "expected the approve panel to render phx-change inputs"

      assert all_phx_change == inside_form,
             "found #{all_phx_change - inside_form} phx-change element(s) outside a <form> — " <>
               "the browser will refuse to send their events"
    end

    test "approves a return", %{conn: conn, store: store} do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "48.50"})
      html = render_click(view, "approve_return")

      assert html =~ "Return approved"

      # Parsed as pesewas, not floats — 48.50 GHS is exactly 4850.
      assert reload(return).status == :approved
      assert reload(return).refund_amount == 4850
    end

    test "caps the notes textarea at the length the approve accepts", %{conn: conn, store: store} do
      # An over-long note fails the approve changeset. The service now discovers
      # that before it asks the gateway, but the browser should not let the
      # merchant hit it at all.
      return = create_return!(store)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})

      assert has_element?(view, "textarea[phx-change='update_notes'][maxlength='2000']")
    end

    test "passes the supplier-at-fault choice through to the refund", %{conn: conn, store: store} do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order)
      supplier = create_supplier!(store)

      create_fulfillment!(store, order,
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 750
      )

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "48.50"})

      view
      |> element("input[phx-click='toggle_dispatch_fee']")
      |> render_click()

      html = render_click(view, "approve_return")

      assert html =~ "Return approved"
      assert reload(return).refund_dispatch_fee? == true
    end

    test "defaults the supplier-at-fault choice to false", %{conn: conn, store: store} do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "48.50"})
      render_click(view, "approve_return")

      assert reload(return).refund_dispatch_fee? == false
    end

    test "shows the refundable balance on the return's payment", %{conn: conn, store: store} do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order, amount: 10_000)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      html = render_click(view, "select_return", %{"id" => return.id})

      assert html =~ "Refundable balance"
      assert html =~ Currency.format_price(10_000)
    end

    test "shows each supplier's dispatch fee alongside its dispatch state", %{
      conn: conn,
      store: store
    } do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order, amount: 10_000)
      supplier = create_supplier!(store)

      create_fulfillment!(store, order,
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 750
      )

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      html = render_click(view, "select_return", %{"id" => return.id})

      assert html =~ supplier.name
      assert html =~ Currency.format_price(750)
      assert html =~ "shipped"
    end

    test "shows the at-fault toggle once a SUPPLIER's fulfillment has dispatched", %{
      conn: conn,
      store: store
    } do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order)
      supplier = create_supplier!(store)

      create_fulfillment!(store, order,
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 750
      )

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})

      assert has_element?(view, "input[phx-click='toggle_dispatch_fee']")
    end

    test "hides the at-fault toggle on a dispatched own-stock order", %{conn: conn, store: store} do
      # Every order gets a merchant-owned fulfillment group (nil supplier_id,
      # no dispatch fee) at checkout, so an own-stock order that has shipped
      # has a dispatched fulfillment — but no supplier to be at fault and no
      # dispatch fee to waive. This is the majority case.
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})

      refute has_element?(view, "input[phx-click='toggle_dispatch_fee']")
    end

    test "hides the at-fault toggle when nothing has dispatched yet", %{conn: conn, store: store} do
      order = create_order!(store, :pending)
      return = create_return!(store, order)
      create_successful_payment!(store, order)
      supplier = create_supplier!(store)

      create_fulfillment!(store, order,
        supplier_id: supplier.id,
        status: :pending,
        dispatch_fee: 750
      )

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})

      refute has_element?(view, "input[phx-click='toggle_dispatch_fee']")
    end

    test "refunds an order whose first payment attempt failed", %{conn: conn, store: store} do
      # A failed first attempt leaves its Payment row behind and the retry adds
      # a second one. The refund has to find the successful charge, not give up
      # and treat the order as cash on delivery.
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_failed_payment!(store, order, amount: 10_000)
      create_successful_payment!(store, order, amount: 10_000)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      html = render_click(view, "select_return", %{"id" => return.id})

      assert html =~ "Refundable balance"
      assert html =~ Currency.format_price(10_000)

      render_click(view, "update_refund_amount", %{"amount" => "48.50"})
      html = render_click(view, "approve_return")

      assert html =~ "Return approved"
      assert reload(return).status == :approved
      assert reload(return).refund_amount == 4850
    end

    test "warns without disabling approve when the amount exceeds the protected balance", %{
      conn: conn,
      store: store
    } do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order, amount: 10_000)
      supplier = create_supplier!(store)

      create_fulfillment!(store, order,
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 3_000
      )

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      html = render_click(view, "update_refund_amount", %{"amount" => "90.00"})

      # Refundable 10,000 - protected 3,000 (dispatch_fee on the shipped
      # fulfillment) = a suggested max of 7,000; 9,000 pesewas exceeds it.
      assert html =~ "Above the suggested limit"
      assert html =~ Currency.format_price(7_000)
      refute has_element?(view, "button[phx-click='approve_return'][disabled]")
    end

    test "points the merchant at the provider dashboard when the gateway cannot refund", %{
      conn: conn,
      store: store
    } do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order, gateway: :hubtel)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "48.50"})
      html = render_click(view, "approve_return")

      assert html =~ "Refunds for this payment must be issued in the provider dashboard."
      assert reload(return).status == :requested
    end

    test "refuses to approve without a valid refund amount", %{conn: conn, store: store} do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "not money"})
      html = render_click(view, "approve_return")

      refute html =~ "Return approved"
      assert reload(return).status == :requested
      assert is_nil(reload(return).refund_amount)
    end

    test "refuses an amount larger than the payment", %{conn: conn, store: store} do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      payment = create_successful_payment!(store, order, amount: 5_000)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "50.01"})
      html = render_click(view, "approve_return")

      refute html =~ "Return approved"
      assert reload(return).status == :requested

      assert Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false).refunded_amount ==
               0
    end

    test "survives a second approve click after the first one succeeded", %{
      conn: conn,
      store: store
    } do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "48.50"})
      assert render_click(view, "approve_return") =~ "Return approved"

      # The queued second click arrives after the handler cleared the
      # selection. It used to reach `nil.order_id` and kill the LiveView.
      render_click(view, "approve_return")

      assert render(view) =~ "Review and manage customer return requests"
      assert reload(return).status == :approved
    end

    test "tells the second tab the return was already handled", %{conn: conn, store: store} do
      order = create_order!(store, :delivered)
      return = create_return!(store, order)
      create_successful_payment!(store, order)

      {:ok, tab_a, _html} = live(conn, ~p"/admin/returns")
      {:ok, tab_b, _html} = live(conn, ~p"/admin/returns")

      # Both tabs hold the return as :requested.
      for tab <- [tab_a, tab_b] do
        render_click(tab, "select_return", %{"id" => return.id})
        render_click(tab, "update_refund_amount", %{"amount" => "48.50"})
      end

      assert render_click(tab_a, "approve_return") =~ "Return approved"

      html = render_click(tab_b, "approve_return")

      assert html =~ "This return has already been handled"
      refute html =~ "Return approved"
      assert reload(return).status == :approved
    end

    test "disables the approve button while the refund is in flight", %{
      conn: conn,
      store: store
    } do
      return = create_return!(store)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})

      assert has_element?(
               view,
               "button[phx-click='approve_return'][phx-disable-with='Approving...']"
             )
    end

    test "approves a cash-on-delivery return, then offers Mark as Refunded", %{
      conn: conn,
      store: store
    } do
      # Cash on delivery creates no Payment row — there is nothing to reverse
      # at the gateway, and the merchant settles the cash by hand.
      order = create_order!(store, :delivered)
      return = create_return!(store, order)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "48.50"})
      html = render_click(view, "approve_return")

      assert html =~ "Return approved"
      assert reload(return).status == :approved
      assert reload(return).refund_amount == 4850

      # The return is no longer stuck: the merchant can close it out.
      assert render_click(view, "select_return", %{"id" => return.id}) =~ "Mark as Refunded"
    end

    test "denies a return", %{conn: conn, store: store} do
      _return = create_return!(store)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      returns =
        Emakola.Orders.Return
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!(authorize?: false)

      return = hd(returns)

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_notes", %{"notes" => "Outside return window"})
      html = render_click(view, "deny_return")

      assert html =~ "Return denied"
    end

    test "mark refunded button appears for approved returns", %{conn: conn, store: store} do
      order = create_order!(store, :delivered)
      approved = create_approved_return!(store, order)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      html = render_click(view, "select_return", %{"id" => approved.id})

      assert html =~ "Mark as Refunded"
    end

    test "closes detail panel", %{conn: conn, store: store} do
      return = create_return!(store)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      render_click(view, "select_return", %{"id" => return.id})
      html = render_click(view, "close_detail")

      refute html =~ "Return Details"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/returns")
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

  defp create_order!(store, status) do
    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)

    order =
      order
      |> Ash.Changeset.for_update(:update, %{})
      |> Ash.Changeset.force_change_attribute(:status, status)
      |> Ash.update!(authorize?: false)

    # Every order gets at least one fulfillment at checkout in production
    # (see Emakola.Orders.Fulfillment's moduledoc). The refund guidance
    # panel's at-fault toggle is gated on fulfillment dispatch state, so
    # fixtures need a real one here too — a merchant-owned (no dispatch fee)
    # fulfillment whose status tracks the order's.
    create_fulfillment!(store, order, status: fulfillment_dispatch_status(status))

    order
  end

  defp fulfillment_dispatch_status(:delivered), do: :delivered
  defp fulfillment_dispatch_status(_status), do: :pending

  defp create_supplier!(store, attrs \\ []) do
    default = %{
      store_id: store.id,
      name: "Supplier #{System.unique_integer([:positive])}"
    }

    Emakola.Suppliers.Supplier
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!(authorize?: false)
  end

  defp create_fulfillment!(store, order, attrs) do
    default = %{
      store_id: store.id,
      order_id: order.id,
      status: :pending,
      dispatch_fee: 0
    }

    Emakola.Orders.Fulfillment
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!(authorize?: false)
  end

  defp create_return!(store, order \\ nil, attrs \\ []) do
    order = order || create_order!(store, :delivered)

    default = %{
      store_id: store.id,
      order_id: order.id,
      reason: :defective
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Orders.Return
    |> Ash.Changeset.for_create(:request_return, params)
    |> Ash.create!(authorize?: false)
  end

  defp create_successful_payment!(store, order, attrs \\ []) do
    default = %{
      store_id: store.id,
      order_id: order.id,
      amount: 500_000,
      gateway: :paystack,
      gateway_reference: "PAY-test-#{System.unique_integer([:positive])}-ref"
    }

    Emakola.Payments.Payment
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  defp create_failed_payment!(store, order, attrs \\ []) do
    default = %{
      store_id: store.id,
      order_id: order.id,
      amount: 500_000,
      gateway: :paystack,
      gateway_reference: "PAY-failed-#{System.unique_integer([:positive])}-ref"
    }

    Emakola.Payments.Payment
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:mark_failed, %{})
    |> Ash.update!(authorize?: false)
  end

  defp reload(return), do: Ash.get!(Emakola.Orders.Return, return.id, authorize?: false)

  defp create_approved_return!(store, order) do
    return = create_return!(store, order)

    return
    |> Ash.Changeset.for_update(:approve, %{refund_amount: 4850})
    |> Ash.update!(authorize?: false)
  end
end
