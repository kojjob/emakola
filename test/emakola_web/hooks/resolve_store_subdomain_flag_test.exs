defmodule EmakolaWeb.Hooks.ResolveStoreSubdomainFlagTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()
    %{store: store}
  end

  test "storefront LiveView assigns on_store_subdomain? when served on a subdomain", %{
    conn: conn,
    store: store
  } do
    # ResolveStoreByHost stashes this in conn.private during endpoint resolution;
    # the :browser pipeline copies it into the session for the hook to read.
    conn = Plug.Conn.put_private(conn, :emakola_on_store_subdomain?, true)
    {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}")
    assert :sys.get_state(view.pid).socket.assigns.on_store_subdomain? == true
  end

  test "defaults to false when the flag is absent", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}")
    assert :sys.get_state(view.pid).socket.assigns.on_store_subdomain? == false
  end
end
