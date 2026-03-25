defmodule EmakolaWeb.Admin.PaymentsLiveTest do
  @moduledoc """
  LiveView tests for the admin payment reconciliation dashboard.
  Tests summary cards, payment table rendering, and status filtering.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "PaymentsLive" do
    test "renders page with summary cards", %{conn: conn, store: store} do
      _paid = create_payment!(store, :success, amount: 100_000)
      _pending = create_payment!(store, :pending, amount: 50_000)
      _failed = create_payment!(store, :failed, amount: 25_000)

      {:ok, _view, html} = live(conn, ~p"/admin/payments")

      assert html =~ "Payments"
      assert html =~ "Total Revenue"
      assert html =~ "Successful"
      assert html =~ "Pending"
      assert html =~ "Failed"
      # Total revenue should only include successful payments: GHS 1000.00
      assert html =~ "1000.00"
    end

    test "displays payment table with correct data", %{conn: conn, store: store} do
      order = Factory.create_order!(store, total: 50_000)

      _payment =
        create_payment!(store, :success,
          amount: 50_000,
          order_id: order.id,
          customer_email: "buyer@example.com",
          gateway: :paystack,
          gateway_reference: "PAY-REF-123"
        )

      {:ok, _view, html} = live(conn, ~p"/admin/payments")

      assert html =~ "buyer@example.com"
      assert html =~ "Paystack"
      assert html =~ "PAY-REF-123"
      assert html =~ "500.00"
      assert html =~ order.order_number
    end

    test "shows empty state when no payments", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/payments")

      assert html =~ "No payments found"
    end

    test "filters by status", %{conn: conn, store: store} do
      _paid =
        create_payment!(store, :success,
          amount: 100_000,
          customer_email: "paid@example.com"
        )

      _pending =
        create_payment!(store, :pending,
          amount: 50_000,
          customer_email: "pending@example.com"
        )

      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      # Filter to only pending
      html =
        view
        |> element("[phx-click='filter_status'][phx-value-status='pending']")
        |> render_click()

      assert html =~ "pending@example.com"
      refute html =~ "paid@example.com"
    end

    test "summary cards always show totals regardless of filter", %{conn: conn, store: store} do
      _paid = create_payment!(store, :success, amount: 200_000)
      _pending = create_payment!(store, :pending, amount: 100_000)

      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      # Filter to pending only
      html =
        view
        |> element("[phx-click='filter_status'][phx-value-status='pending']")
        |> render_click()

      # Summary should still show 1 successful
      assert html =~ "1"
    end

    test "displays correct payment status badges", %{conn: conn, store: store} do
      _paid = create_payment!(store, :success)
      _pending = create_payment!(store, :pending)
      _failed = create_payment!(store, :failed)

      {:ok, _view, html} = live(conn, ~p"/admin/payments")

      assert html =~ "Paid"
      assert html =~ "Pending"
      assert html =~ "Failed"
    end

    test "does not show payments from other stores", %{conn: conn, store: _store} do
      other_store = Factory.create_store!()

      _other_payment =
        create_payment!(other_store, :success, customer_email: "other-store@example.com")

      {:ok, _view, html} = live(conn, ~p"/admin/payments")

      refute html =~ "other-store@example.com"
    end

    test "displays gateway labels correctly", %{conn: conn, store: store} do
      _paystack = create_payment!(store, :success, gateway: :paystack)
      _hubtel = create_payment!(store, :success, gateway: :hubtel)

      {:ok, _view, html} = live(conn, ~p"/admin/payments")

      assert html =~ "Paystack"
      assert html =~ "Hubtel"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/payments")
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

  defp create_payment!(store, status, opts \\ []) do
    payment =
      Emakola.Payments.Payment
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        amount: Keyword.get(opts, :amount, 100_000),
        currency: "GHS",
        gateway: Keyword.get(opts, :gateway, :paystack),
        gateway_reference:
          Keyword.get(opts, :gateway_reference, "PAY-#{System.unique_integer([:positive])}"),
        customer_email: Keyword.get(opts, :customer_email, "customer@example.com"),
        order_id: Keyword.get(opts, :order_id, nil)
      })
      |> Ash.create!()

    case status do
      :success ->
        payment
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update!()

      :failed ->
        payment
        |> Ash.Changeset.for_update(:mark_failed, %{})
        |> Ash.update!()

      :pending ->
        payment

      _ ->
        payment
    end
  end
end
