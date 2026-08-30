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

  describe "payment dashboard tiles" do
    test "five tiles report volume, count, success rate, failed and refunded", %{
      conn: conn,
      store: store
    } do
      create_payment!(store, :success, amount: 100_000)
      create_payment!(store, :success, amount: 50_000)
      create_payment!(store, :pending, amount: 25_000)
      create_payment!(store, :failed, amount: 10_000)

      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      assert has_element?(view, "#stat-payments-volume", "GH₵ 1,500")
      assert has_element?(view, "#stat-payments-count", "4")
      # 2 of 4 succeeded.
      assert has_element?(view, "#stat-payments-rate", "50")
      assert has_element?(view, "#stat-payments-failed", "1")
      assert has_element?(view, "#stat-payments-refunded")
    end

    test "a store with no payments reports zero rather than dividing by it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      # success/total with total = 0 must not raise.
      assert has_element?(view, "#stat-payments-rate", "0")
    end
  end

  describe "charts" do
    test "the three canvases render with their chart types", %{conn: conn, store: store} do
      create_payment!(store, :success, amount: 40_000)

      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      assert has_element?(view, "canvas#payments-volume-chart[data-chart-type='gmv-line']")
      assert has_element?(view, "canvas#payments-status-chart[data-chart-type='status-bar']")

      assert has_element?(
               view,
               "canvas#payments-provider-chart[data-chart-type='provider-donut']"
             )
    end

    test "the provider ring is labelled by gateway with a real total", %{
      conn: conn,
      store: store
    } do
      create_payment!(store, :success, amount: 60_000, gateway: :paystack)
      create_payment!(store, :success, amount: 40_000, gateway: :hubtel)

      {:ok, view, html} = live(conn, ~p"/admin/payments")

      assert html =~ "Paystack"
      assert html =~ "Hubtel"
      # Centre total is markup, not part of the ring.
      assert has_element?(view, "#payments-provider-total", "GH₵ 1,000")
    end

    test "the volume chart accounts for money the tile counts", %{conn: conn, store: store} do
      old = create_payment!(store, :success, amount: 80_000)
      backdate!(old, -100)

      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      html =
        view
        |> element("#payments-range-tabs button[phx-value-range='all']")
        |> render_click()

      # The tile says GH₵ 800; a chart that sums to zero over the same range
      # contradicts it. Capping the window at 30 days did exactly that.
      assert html =~ "GH₵ 800"

      charted =
        html
        |> then(&Regex.run(~r/id="payments-volume-chart"[^>]*data-chart-data="([^"]*)"/, &1))
        |> List.last()
        |> String.replace("&quot;", "\"")
        |> Jason.decode!()
        |> Map.fetch!("values")
        |> Enum.sum()

      assert charted == 80_000,
             "the volume chart totals #{charted}, but the range holds 80000"
    end

    test "every chart type used in the app exists in the JS config" do
      # chart_hook.js silently renders nothing for an unknown chart type — no
      # chart, no console error. This is the only thing that catches a typo or
      # a config that was never added.
      hook = File.read!(Path.expand("../../../../assets/js/hooks/chart_hook.js", __DIR__))

      used =
        "lib/emakola_web"
        |> Path.expand(Path.expand("../../../../", __DIR__))
        |> then(&Path.wildcard(Path.join(&1, "**/*.ex")))
        |> Enum.flat_map(fn file ->
          Regex.scan(~r/data-chart-type="([a-z-]+)"/, File.read!(file), capture: :all_but_first)
        end)
        |> List.flatten()
        |> Enum.uniq()

      for type <- used do
        assert hook =~ "\"#{type}\":",
               "chart type #{inspect(type)} is used in a template but has no CHART_CONFIGS " <>
                 "entry — it renders a blank card with no error"
      end
    end

    test "chart money labels use the cedi symbol the rest of the app uses" do
      # Currency.format_price/2 renders GH₵ everywhere. Chart.js cannot read it
      # from Elixir, so the symbol is duplicated in JS — where it silently drifts.
      hook = File.read!(Path.expand("../../../../assets/js/hooks/chart_hook.js", __DIR__))

      refute hook =~ ~r/GHS\s/,
             "chart_hook.js labels money as \"GHS\" but every other surface says " <>
               "#{EmakolaWeb.Helpers.Currency.currency_symbol("GHS")} — the same amount " <>
               "reads two ways depending on whether you look at the tile or the chart"
    end
  end

  describe "range and table agree" do
    # The tiles were range-scoped and the table was not, so "Money in GH₵ 0"
    # sat directly above a table listing five payments from April.
    test "a payment outside the range leaves the table too", %{conn: conn, store: store} do
      recent = create_payment!(store, :success, amount: 40_000)
      old = create_payment!(store, :success, amount: 90_000)
      backdate!(old, -45)

      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      table = view |> element("#payments-table") |> render()

      assert table =~ recent.gateway_reference
      refute table =~ old.gateway_reference
    end
  end

  describe "date range" do
    test "the range narrows what the tiles count", %{conn: conn, store: store} do
      recent = create_payment!(store, :success, amount: 40_000)
      old = create_payment!(store, :success, amount: 90_000)
      backdate!(old, -45)

      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      # Default range is the last 7 days: only the recent payment counts.
      assert has_element?(view, "#stat-payments-volume", "GH₵ 400")
      refute has_element?(view, "#stat-payments-volume", "GH₵ 1,300")

      html =
        view
        |> element("#payments-range-tabs button[phx-value-range='all']")
        |> render_click()

      assert html =~ "GH₵ 1,300"
      assert recent.id
    end
  end

  describe "PaymentsLive" do
    test "renders page with summary cards", %{conn: conn, store: store} do
      _paid = create_payment!(store, :success, amount: 100_000)
      _pending = create_payment!(store, :pending, amount: 50_000)
      _failed = create_payment!(store, :failed, amount: 25_000)

      {:ok, _view, html} = live(conn, ~p"/admin/payments")

      assert html =~ "Payments"

      # Tile labels are plain language now — "Money in" rather than "Total
      # Revenue" — for merchants who read slowly.
      assert html =~ "Money in"
      assert html =~ "Went through"
      assert html =~ "Did not go through"
      assert html =~ "Sent back"

      # Money in counts successful payments only: GH₵ 1,000
      assert html =~ "1,000"
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
      assert html =~ "500"
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

  # Moves a payment back in time so date-range filtering has something to
  # exclude. inserted_at is not writable through a normal action.
  defp backdate!(payment, days) do
    payment
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.Changeset.force_change_attribute(
      :inserted_at,
      DateTime.add(DateTime.utc_now(), days, :day)
    )
    |> Ash.update!(authorize?: false)
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
      |> Ash.create!(authorize?: false)

    case status do
      :success ->
        payment
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update!(authorize?: false)

      :failed ->
        payment
        |> Ash.Changeset.for_update(:mark_failed, %{})
        |> Ash.update!(authorize?: false)

      :pending ->
        payment

      _ ->
        payment
    end
  end
end
