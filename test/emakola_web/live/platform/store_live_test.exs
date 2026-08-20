defmodule EmakolaWeb.Platform.StoreLiveTest do
  @moduledoc """
  Permission gating for /platform/stores (requires :manage_stores),
  disconnected-mount loading shell, event re-authorisation after
  permission revocation, the Directory Studio split view (store
  selection, curation panel toggles, rank stepper, quick filters,
  suspended-store banner), and platform layout regressions: the logout
  link must issue DELETE /platform/session, the sidebar Stores link is
  permission-gated, and the user popover links to /platform/security.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  defp set_permissions!(user, permissions) do
    user
    |> Ash.Changeset.for_update(:set_platform_permissions, %{platform_permissions: permissions})
    |> Ash.update!(authorize?: false)
  end

  defp suspend!(store) do
    Emakola.Stores.suspend_store(store, %{reason: "test suspension"}, authorize?: false)
  end

  describe "permission gating" do
    test "owner can mount /platform/stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, view, html} = live(conn, "/platform/stores")
      assert html =~ "Stores"
      assert has_element?(view, "#platform-stores[phx-update='stream']")
    end

    test "staff with :manage_stores can mount /platform/stores", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      refute user.is_owner
      {:ok, _view, html} = live(conn, "/platform/stores")
      assert html =~ "Stores"
    end

    test "staff without :manage_stores is bounced to /platform with a flash", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, "/platform/stores")

      assert flash["error"] =~ "permission"
    end
  end

  describe "disconnected mount" do
    test "renders a loading shell without hitting the database", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      _store = Factory.create_store!()

      conn = get(conn, "/platform/stores")

      html = html_response(conn, 200)
      assert html =~ "loading"
      refute html =~ "test-store"
    end
  end

  describe "event re-authorization" do
    test "toggle_featured blocked when :manage_stores revoked after mount", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(featured: false)

      {:ok, view, _html} = live(conn, "/platform/stores")

      # Revoke the permission in the DB after the socket is already mounted.
      set_permissions!(user, [:manage_team])

      html = render_click(view, "toggle_featured", %{"id" => store.id})

      assert html =~ "don&#39;t have permission"
      # The store must not have been modified.
      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      refute reloaded.featured
    end

    test "toggle_verified blocked when :manage_stores revoked after mount", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(verified: false)

      {:ok, view, _html} = live(conn, "/platform/stores")

      set_permissions!(user, [:manage_team])

      html = render_click(view, "toggle_verified", %{"id" => store.id})

      assert html =~ "don&#39;t have permission"
      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      refute reloaded.verified
    end

    test "adjust_rank blocked when :manage_stores revoked after mount", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(featured: true, featured_rank: 1)

      {:ok, view, _html} = live(conn, "/platform/stores")

      set_permissions!(user, [:manage_team])

      html = render_click(view, "adjust_rank", %{"id" => store.id, "dir" => "up"})

      assert html =~ "don&#39;t have permission"
      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).featured_rank == 1
    end
  end

  describe "store selection" do
    test "the only store is selected by default and the panel shows it", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(name: "Panel Default Shop")

      {:ok, view, _html} = live(conn, "/platform/stores")

      assert has_element?(view, "#store-#{store.id}[data-selected]")
      assert has_element?(view, "#store-panel", "Panel Default Shop")
    end

    test "clicking a row selects that store in the panel", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      first = Factory.create_store!(name: "First Selectable")
      second = Factory.create_store!(name: "Second Selectable")

      {:ok, view, _html} = live(conn, "/platform/stores")

      view |> element("#store-#{first.id}") |> render_click()

      assert has_element?(view, "#store-#{first.id}[data-selected]")
      refute has_element?(view, "#store-#{second.id}[data-selected]")
      assert has_element?(view, "#store-panel", "First Selectable")

      view |> element("#store-#{second.id}") |> render_click()

      assert has_element?(view, "#store-#{second.id}[data-selected]")
      refute has_element?(view, "#store-#{first.id}[data-selected]")
      assert has_element?(view, "#store-panel", "Second Selectable")
    end

    test "an empty roster shows an empty state and no panel", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      {:ok, view, html} = live(conn, "/platform/stores")

      refute has_element?(view, "#store-panel")
      assert html =~ "No stores found"
    end
  end

  describe "curation panel" do
    test "featured toggle features the selected store", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(featured: false)

      {:ok, view, _html} = live(conn, "/platform/stores")

      assert has_element?(view, "#panel-featured-toggle[aria-checked='false']")

      view |> element("#panel-featured-toggle") |> render_click()

      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).featured
      assert has_element?(view, "#panel-featured-toggle[aria-checked='true']")
    end

    test "verified toggle verifies the selected store", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(verified: false)

      {:ok, view, _html} = live(conn, "/platform/stores")

      view |> element("#panel-verified-toggle") |> render_click()

      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).verified
      assert has_element?(view, "#panel-verified-toggle[aria-checked='true']")
    end

    test "a suspended store's panel explains it is hidden from the directory", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(name: "Hidden Shop")
      {:ok, _suspended} = suspend!(store)

      {:ok, view, _html} = live(conn, "/platform/stores")

      assert has_element?(view, "#store-panel", "Hidden Shop")
      assert has_element?(view, "#panel-hidden-banner")
      assert render(view) =~ "hidden from the public directory"
    end

    test "a live store's panel shows no hidden banner", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      _store = Factory.create_store!()

      {:ok, view, _html} = live(conn, "/platform/stores")

      refute has_element?(view, "#panel-hidden-banner")
    end
  end

  describe "rank stepper" do
    test "up from no rank sets rank 1", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(featured: true, featured_rank: nil)

      {:ok, view, _html} = live(conn, "/platform/stores")

      assert has_element?(view, "#panel-rank-value", "—")

      view |> element("#panel-rank-up") |> render_click()

      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).featured_rank == 1
      assert has_element?(view, "#panel-rank-value", "1")
    end

    test "up increments an existing rank", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(featured: true, featured_rank: 2)

      {:ok, view, _html} = live(conn, "/platform/stores")

      view |> element("#panel-rank-up") |> render_click()

      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).featured_rank == 3
      assert has_element?(view, "#panel-rank-value", "3")
    end

    test "down at rank 1 clears the rank", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(featured: true, featured_rank: 1)

      {:ok, view, _html} = live(conn, "/platform/stores")

      view |> element("#panel-rank-down") |> render_click()

      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).featured_rank == nil
      assert has_element?(view, "#panel-rank-value", "—")
    end

    test "down decrements a rank above 1", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!(featured: true, featured_rank: 3)

      {:ok, view, _html} = live(conn, "/platform/stores")

      view |> element("#panel-rank-down") |> render_click()

      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).featured_rank == 2
      assert has_element?(view, "#panel-rank-value", "2")
    end
  end

  describe "quick filters" do
    test "featured filter narrows the list to featured stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      featured = Factory.create_store!(featured: true)
      plain = Factory.create_store!(featured: false)

      {:ok, view, _html} = live(conn, "/platform/stores")

      assert has_element?(view, "#platform-stores[data-count='2']")

      view |> element("#filter-featured") |> render_click()

      assert has_element?(view, "#platform-stores[data-count='1']")
      assert has_element?(view, "#store-#{featured.id}")
      refute has_element?(view, "#store-#{plain.id}")
    end

    test "suspended filter shows only stores hidden from the directory", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      live_store = Factory.create_store!()
      suspended = Factory.create_store!()
      {:ok, _} = suspend!(suspended)

      {:ok, view, _html} = live(conn, "/platform/stores")

      view |> element("#filter-suspended") |> render_click()

      assert has_element?(view, "#platform-stores[data-count='1']")
      assert has_element?(view, "#store-#{suspended.id}")
      refute has_element?(view, "#store-#{live_store.id}")
    end

    test "all filter restores the full list", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      _featured = Factory.create_store!(featured: true)
      _plain = Factory.create_store!(featured: false)

      {:ok, view, _html} = live(conn, "/platform/stores")

      view |> element("#filter-featured") |> render_click()
      assert has_element?(view, "#platform-stores[data-count='1']")

      view |> element("#filter-all") |> render_click()
      assert has_element?(view, "#platform-stores[data-count='2']")
    end
  end

  describe "streamed directory" do
    test "search resets the store stream", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      matching = Factory.create_store!(name: "Stream Needle Shop", slug: "stream-needle-shop")
      other = Factory.create_store!(name: "Different Market", slug: "different-market")

      {:ok, view, _html} = live(conn, "/platform/stores")

      assert has_element?(view, "#store-#{matching.id}")
      assert has_element?(view, "#store-#{other.id}")

      view
      |> form("#platform-store-search-form", %{"search" => "Needle"})
      |> render_change()

      assert has_element?(view, "#platform-stores[phx-update='stream'][data-count='1']")
      assert has_element?(view, "#store-#{matching.id}")
      refute has_element?(view, "#store-#{other.id}")
    end
  end

  describe "platform layout" do
    test "logout links issue DELETE /platform/session", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform")

      assert html =~ ~s(href="/platform/session")
      assert html =~ ~s(data-method="delete")
      refute html =~ ~s(href="/auth/session")
    end

    test "sidebar hides the Stores link without :manage_stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      {:ok, _view, html} = live(conn, "/platform")
      refute html =~ ~s(href="/platform/stores")
    end

    test "sidebar shows the Stores link with :manage_stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      {:ok, _view, html} = live(conn, "/platform")
      assert html =~ ~s(href="/platform/stores")
    end

    test "Merchants links to /platform/merchants for staff with :manage_merchants", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform")

      assert html =~ ~s(href="/platform/merchants")
      assert html =~ "Merchants"
    end

    test "user popover links to /platform/security, not /admin/settings", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform")

      assert html =~ ~s(href="/platform/security")
      assert html =~ "Security"
      refute html =~ ~s(href="/admin/settings")
    end
  end
end
