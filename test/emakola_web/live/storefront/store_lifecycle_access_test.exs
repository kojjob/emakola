defmodule EmakolaWeb.Storefront.StoreLifecycleAccessTest do
  @moduledoc """
  End-to-end enforcement: the `ResolveStore` on_mount hook must stop a non-live
  store from serving ANY storefront page. Suspended/blocked → the neutral
  /store-unavailable page; archived → hidden (redirect home).
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Stores

  test "a live store's storefront renders", %{conn: conn} do
    store = Factory.create_store!()
    assert {:ok, _view, _html} = live(conn, "/s/#{store.slug}")
  end

  test "a suspended store redirects to /store-unavailable", %{conn: conn} do
    {:ok, store} =
      Stores.suspend_store(Factory.create_store!(), %{reason: "x"}, authorize?: false)

    assert {:error, {:redirect, %{to: "/store-unavailable"}}} = live(conn, "/s/#{store.slug}")
  end

  test "a blocked store redirects to /store-unavailable", %{conn: conn} do
    {:ok, store} =
      Stores.block_store(Factory.create_store!(), %{reason: "x"}, authorize?: false)

    assert {:error, {:redirect, %{to: "/store-unavailable"}}} = live(conn, "/s/#{store.slug}")
  end

  test "an archived store answers 410 so search engines drop it", %{conn: conn} do
    {:ok, store} = Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)
    assert_error_sent 410, fn -> get(conn, "/#{store.slug}") end
  end

  test "the /store-unavailable page renders without a store context", %{conn: conn} do
    assert {:ok, _view, html} = live(conn, "/store-unavailable")
    assert html =~ "currently unavailable"
  end
end
