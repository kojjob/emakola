defmodule EmakolaWeb.Storefront.SubdomainLinksTest do
  @moduledoc """
  Verifies storefront navigational links route through `Storefront.Path`:
  on a store's own subdomain they drop the `/s/:slug` prefix, on the apex they
  keep it. Uses the customer login page because it renders its links straight
  from the LiveView template (not via a theme module), so the converted call
  sites are exercised directly.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()
    %{store: store}
  end

  test "on the subdomain, nav links omit /s/:slug", %{conn: conn, store: store} do
    conn = Plug.Test.init_test_session(conn, %{"on_store_subdomain?" => true})
    {:ok, _v, html} = live(conn, "/s/#{store.slug}/login")
    assert html =~ ~s(href="/whatsapp")
    refute html =~ ~s(href="/s/#{store.slug}/whatsapp")
  end

  test "on the apex, nav links keep /s/:slug", %{conn: conn, store: store} do
    {:ok, _v, html} = live(conn, "/s/#{store.slug}/login")
    assert html =~ ~s(href="/s/#{store.slug}/whatsapp")
    refute html =~ ~s(href="/whatsapp")
  end
end
