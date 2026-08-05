defmodule EmakolaWeb.Platform.MerchantLive.IndexTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  describe "permission gating" do
    test "owner can mount /platform/merchants", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "Merchants"
    end

    test "staff with :manage_merchants can mount", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_merchants])
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "Merchants"
    end

    test "staff without :manage_merchants is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, ~p"/platform/merchants")

      assert flash["error"] =~ "permission"
    end
  end

  describe "disconnected mount" do
    test "renders a loading shell without hitting the database", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      Factory.create_merchant!(%{name: "Ama Mensah", email: "ama@example.com"})

      conn = get(conn, ~p"/platform/merchants")
      html = html_response(conn, 200)

      assert html =~ "Loading merchants"
      refute html =~ "Ama Mensah"
    end
  end

  describe "listing & stats" do
    setup %{conn: conn} do
      ts = DateTime.utc_now()

      ama =
        Factory.create_merchant!(%{
          name: "Ama Mensah",
          email: "ama@example.com",
          business_name: "Ama Foods",
          confirmed_at: ts
        })

      yaw = Factory.create_merchant!(%{name: "Yaw Owusu", email: "yaw@example.com"})
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, conn: conn, ama: ama, yaw: yaw}
    end

    test "renders merchants with names and emails", %{conn: conn, ama: ama, yaw: yaw} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      assert has_element?(view, "#platform-merchants[phx-update='stream'][data-count='2']")
      assert has_element?(view, "#merchant-#{ama.id}", "Ama Mensah")
      assert has_element?(view, "#merchant-#{yaw.id}", "Yaw Owusu")
    end

    test "stat strip shows labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "Total"
      assert html =~ "Confirmed"
      assert html =~ "With a store"
      assert html =~ "New"
    end

    test "search narrows by name", %{conn: conn, ama: ama, yaw: yaw} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      view |> form("#merchant-search-form") |> render_change(%{"search" => "Ama"})
      assert has_element?(view, "#platform-merchants[data-count='1']")
      assert has_element?(view, "#merchant-#{ama.id}")
      refute has_element?(view, "#merchant-#{yaw.id}")
    end

    test "search narrows by email", %{conn: conn, ama: ama, yaw: yaw} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      view |> form("#merchant-search-form") |> render_change(%{"search" => "yaw@"})
      assert has_element?(view, "#merchant-#{yaw.id}")
      refute has_element?(view, "#merchant-#{ama.id}")
    end

    test "unconfirmed filter shows only unconfirmed merchants", %{conn: conn, ama: ama, yaw: yaw} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      render_click(view, "filter", %{"filter" => "unconfirmed"})
      assert has_element?(view, "#merchant-#{yaw.id}")
      refute has_element?(view, "#merchant-#{ama.id}")
    end

    test "an empty search result renders the streamed empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")

      view
      |> form("#merchant-search-form")
      |> render_change(%{"search" => "does-not-exist"})

      assert has_element?(view, "#platform-merchants[data-count='0']")
      assert has_element?(view, "#platform-merchants-empty")
    end

    test "a forged selection outside the current search result is ignored", %{
      conn: conn,
      yaw: yaw
    } do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")

      view |> form("#merchant-search-form") |> render_change(%{"search" => "Ama"})
      html = render_click(view, "select_merchant", %{"id" => yaw.id})

      refute html =~ "Yaw Owusu"
      refute html =~ "yaw@example.com"
    end
  end

  describe "drill-down drawer" do
    test "selecting a merchant loads their stores and roles", %{conn: conn} do
      m = Factory.create_merchant!(%{name: "Esi Owl", email: "esi@example.com"})
      store = Factory.create_store!(%{name: "Owl Boutique"})
      Factory.create_store_membership!(m, store, :owner)
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      html = render_click(view, "select_merchant", %{"id" => m.id})

      assert html =~ "Esi Owl"
      assert html =~ "Owl Boutique"
      assert html =~ "owner"
    end
  end

  describe "empty state" do
    test "renders when no merchants exist", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "No merchants yet"
    end
  end
end
