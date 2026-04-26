defmodule EmakolaWeb.Admin.ReturnLiveTest do
  @moduledoc """
  LiveView tests for the admin return management page.
  Tests return listing, filtering, approve/deny actions, and empty state.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

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

    test "approves a return", %{conn: conn, store: store} do
      _return = create_return!(store)

      {:ok, view, _html} = live(conn, ~p"/admin/returns")

      returns =
        Emakola.Orders.Return
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!(authorize?: false)

      return = hd(returns)

      render_click(view, "select_return", %{"id" => return.id})
      render_click(view, "update_refund_amount", %{"amount" => "48.50"})
      html = render_click(view, "approve_return")

      assert html =~ "Return approved"
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
    subject = AshAuthentication.user_to_subject(merchant)

    conn
    |> init_test_session(%{"user_token" => subject})
  end

  defp create_order!(store, status) do
    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)

    order
    |> Ash.Changeset.for_update(:update, %{})
    |> Ash.Changeset.force_change_attribute(:status, status)
    |> Ash.update!(authorize?: false)
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

  defp create_approved_return!(store, order) do
    return = create_return!(store, order)

    return
    |> Ash.Changeset.for_update(:approve, %{refund_amount: 4850})
    |> Ash.update!(authorize?: false)
  end
end
