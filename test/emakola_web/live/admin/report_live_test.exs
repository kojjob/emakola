defmodule EmakolaWeb.Admin.ReportLiveTest do
  @moduledoc """
  LiveView tests for the admin reports page.

  The page shipped 1,035 lines with zero data access: hand-plotted SVG
  coordinates, a "Sales by Channel" donut (Instagram 45% …), a conversion
  rate, per-region conversion, and three "AI Insights" paragraphs — all
  invented, all shown to real merchants.

  Anything needing visit or session tracking is GONE rather than wired:
  no such tracking exists in this codebase, so a conversion rate has no
  denominator and channel share has no numerator. What remains is what
  orders can actually answer.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "ReportLive.Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/reports")
    end
  end

  describe "ReportLive.Index (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders reports page heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Reports"
    end

    test "revenue and order count come from this store's orders", %{conn: conn, store: store} do
      Factory.create_order!(store, total: 40_000, status: :confirmed)
      Factory.create_order!(store, total: 25_000, status: :confirmed)

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      assert has_element?(view, "#stat-reports-revenue", "650.00")
      assert has_element?(view, "#stat-reports-orders", "2")
    end

    test "average order value is derived, not stored", %{conn: conn, store: store} do
      Factory.create_order!(store, total: 30_000, status: :confirmed)
      Factory.create_order!(store, total: 10_000, status: :confirmed)

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      assert has_element?(view, "#stat-reports-aov", "200.00")
    end

    test "another store's orders never appear", %{conn: conn, store: store} do
      Factory.create_order!(store, total: 40_000, status: :confirmed)

      other = Factory.create_store!()
      Factory.create_order!(other, total: 900_000, status: :confirmed)

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      assert has_element?(view, "#stat-reports-revenue", "400.00")
      refute render(view) =~ "9,000.00"
    end

    test "the range filter narrows what is counted", %{conn: conn, store: store} do
      Factory.create_order!(store, total: 40_000, status: :confirmed)
      old = Factory.create_order!(store, total: 90_000, status: :confirmed)
      backdate!(old, -120)

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      assert has_element?(view, "#stat-reports-revenue", "400.00")

      html =
        view
        |> element("button[phx-click='set_date_range'][phx-value-range='12m']")
        |> render_click()

      assert html =~ "1,300.00"
    end

    test "the revenue chart is a real chart fed by real rows", %{conn: conn, store: store} do
      Factory.create_order!(store, total: 40_000)

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      assert has_element?(view, "#reports-revenue-chart[data-chart-type='gmv-line']")
    end

    test "an empty store reports zeros, not a fabricated dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      # Scoped to the tiles rather than matched against the whole document.
      # `refute html =~ "284"` searched the page including the CSRF token and
      # the data-phx-session blob — kilobytes of random base64 — so roughly one
      # run in sixty failed because three random characters happened to spell
      # the number it was guarding against.
      refute has_element?(view, "#stat-reports-revenue", "38,470")
      refute has_element?(view, "#stat-reports-aov", "135.46")
      refute has_element?(view, "#stat-reports-orders", "284")
    end

    # There is no visit or session tracking in this codebase. A conversion
    # rate has no denominator and channel share has no numerator, so these
    # were removed rather than wired to something that looks similar.
    test "no metric that needs visit tracking survives", %{conn: conn, store: store} do
      Factory.create_order!(store, total: 40_000)

      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      # "Instagram" and "TikTok" are not on this list: they are now real
      # source labels on paid orders and visits (Emakola.Orders.Source),
      # rendered only when data earns them. What is guarded here is the
      # specific invented donut this page used to show.
      for invented <- [
            "Conversion Rate",
            "Sales by Channel",
            "Instagram 45%",
            "TikTok 4%",
            "total visits",
            "AI Insights",
            "Kente Wrap Dress",
            "Beaded Choker",
            "128 new customers this month",
            "Top source"
          ] do
        refute html =~ invented, "the page still renders #{invented}"
      end
    end

    test "renders date range toggle buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "7D"
      assert html =~ "30D"
      assert html =~ "12M"
    end
  end

  # inserted_at is not writable through a normal action.
  defp backdate!(order, days) do
    order
    |> Ash.Changeset.for_update(:update, %{})
    |> Ash.Changeset.force_change_attribute(
      :inserted_at,
      DateTime.add(DateTime.utc_now(), days, :day)
    )
    |> Ash.update!(authorize?: false)
  end

  describe "traffic" do
    setup %{conn: conn} do
      {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, store: store}
    end

    test "a store with no visits reports no rate rather than 0%", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      # This page was rebuilt because it showed merchants invented figures.
      # "0% of them bought" would be a claim about conversion made from no data
      # at all — the same mistake in a smaller font.
      assert has_element?(view, "#stat-reports-visitors", "No visits yet")
      refute has_element?(view, "#stat-reports-visitors", "% of them bought")
    end

    test "visitors are counted, and pageviews are not mistaken for people", %{
      conn: conn,
      store: store
    } do
      # Two people, one of whom browsed three pages.
      for _ <- 1..3, do: Emakola.Analytics.StoreVisits.record(store.id, "person-a", %{})
      Emakola.Analytics.StoreVisits.record(store.id, "person-b", %{})

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      assert has_element?(view, "#stat-reports-visitors", "2")
    end

    test "conversion is orders over visitors", %{conn: conn, store: store} do
      customer = Emakola.Factory.create_customer!(store)

      Emakola.Factory.create_order!(store, %{customer_id: customer.id, status: :delivered})

      for id <- ["a", "b", "c", "d"],
          do: Emakola.Analytics.StoreVisits.record(store.id, id, %{})

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      # 1 order, 4 visitors.
      assert has_element?(view, "#stat-reports-visitors", "25.0% of them bought")
    end

    test "more orders than visitors is not a rate above 100%", %{conn: conn, store: store} do
      # Orders are counted from the store's whole history, visits only from the
      # day counting shipped, so every store starts with orders far exceeding
      # visitors. Dividing anyway produced "1.5e3% of them bought" — scientific
      # notation, because Float.to_string/1 emits the shortest round-trip form
      # for round values at 1000 and above.
      customer = Emakola.Factory.create_customer!(store)

      for _ <- 1..15,
          do:
            Emakola.Factory.create_order!(store, %{customer_id: customer.id, status: :delivered})

      Emakola.Analytics.StoreVisits.record(store.id, "only-visitor", %{})

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      # Scoped to the tile, never the whole document: the phx-session blob is
      # random base64 and would match a short literal by chance. See #475.
      assert has_element?(view, "#stat-reports-visitors", "Still counting visits")
      refute has_element?(view, "#stat-reports-visitors", "of them bought")
      refute has_element?(view, "#stat-reports-visitors", "e3")
    end

    test "visitors who did not buy still get a rate", %{conn: conn, store: store} do
      # Nobody bought is a real answer and needs no guard: the denominator is
      # whole, so 0.0% is a fact about traffic rather than an invented figure.
      for id <- ["a", "b"], do: Emakola.Analytics.StoreVisits.record(store.id, id, %{})

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      assert has_element?(view, "#stat-reports-visitors", "0.0% of them bought")
    end

    test "one store's traffic never appears in another's report", %{conn: conn} do
      elsewhere = Emakola.Factory.create_store!()
      for id <- ["x", "y"], do: Emakola.Analytics.StoreVisits.record(elsewhere.id, id, %{})

      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      assert has_element?(view, "#stat-reports-visitors", "No visits yet")
    end
  end
end
