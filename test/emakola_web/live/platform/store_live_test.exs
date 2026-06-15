defmodule EmakolaWeb.Platform.StoreLiveTest do
  @moduledoc """
  Permission gating for /platform/stores (requires :manage_stores),
  disconnected-mount loading shell, event re-authorisation after
  permission revocation, and platform layout regressions: the logout
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

  describe "permission gating" do
    test "owner can mount /platform/stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform/stores")
      assert html =~ "Stores"
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
