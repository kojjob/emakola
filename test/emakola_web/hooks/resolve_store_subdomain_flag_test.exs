defmodule EmakolaWeb.Hooks.ResolveStoreSubdomainFlagTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()
    %{store: store}
  end

  test "storefront LiveView assigns on_store_subdomain? when the session flag is set", %{
    conn: conn,
    store: store
  } do
    # Host-routed storefront requests carry this flag in the session
    # (ResolveStoreHost sets it); the /s/:slug ResolveStore hook reads it.
    conn = Phoenix.ConnTest.init_test_session(conn, %{"on_store_subdomain?" => true})
    {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}")
    assert :sys.get_state(view.pid).socket.assigns.on_store_subdomain? == true
  end

  test "defaults to false when the flag is absent", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}")
    assert :sys.get_state(view.pid).socket.assigns.on_store_subdomain? == false
  end
end
