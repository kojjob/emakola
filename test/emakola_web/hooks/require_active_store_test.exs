defmodule EmakolaWeb.Hooks.RequireActiveStoreTest do
  @moduledoc """
  A merchant whose store the platform has suspended/blocked/archived must be
  locked out of the admin and sent to /store-locked — but a merchant who merely
  closed their OWN store (active=false, status=:active) keeps full access.
  """
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Stores

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  test "a live store's merchant reaches the dashboard", %{conn: conn} do
    assert {:ok, _view, _html} = live(conn, "/dashboard")
  end

  test "a suspended store's merchant is redirected to /store-locked", %{conn: conn, store: store} do
    {:ok, _} = Stores.suspend_store(store, %{reason: "Policy review"}, authorize?: false)
    assert {:error, {:redirect, %{to: "/store-locked"}}} = live(conn, "/dashboard")
  end

  test "a merchant who closed their OWN store keeps admin access", %{conn: conn, store: store} do
    {:ok, _} = Stores.update_store_settings(store, %{active: false}, authorize?: false)
    assert {:ok, _view, _html} = live(conn, "/dashboard")
  end

  test "the /store-locked page shows the suspension reason", %{conn: conn, store: store} do
    {:ok, _} = Stores.suspend_store(store, %{reason: "Policy review"}, authorize?: false)
    assert {:ok, _view, html} = live(conn, "/store-locked")
    assert html =~ "Policy review"
    assert html =~ "unavailable"
  end

  test "the /store-locked page bounces a merchant whose store is live", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, "/store-locked")
  end
end
