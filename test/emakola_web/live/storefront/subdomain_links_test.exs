defmodule EmakolaWeb.Storefront.SubdomainLinksTest do
  @moduledoc """
  Verifies storefront navigational links route through `Storefront.Path`:
  on a store's own subdomain they drop the `/s/:slug` prefix, on the apex they
  keep it. Covers both conversion surfaces — a LiveView-rendered page (customer
  login) and a theme-rendered page (the store home, via the default theme).
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()
    %{store: store}
  end

  test "on the subdomain, nav links omit /s/:slug", %{conn: conn, store: store} do
    conn = Plug.Conn.put_private(conn, :emakola_on_store_subdomain?, true)
    {:ok, _v, html} = live(conn, "/s/#{store.slug}/login")
    assert html =~ ~s(href="/whatsapp")
    refute html =~ ~s(href="/s/#{store.slug}/whatsapp")
  end

  test "on the apex, nav links keep /s/:slug", %{conn: conn, store: store} do
    {:ok, _v, html} = live(conn, "/s/#{store.slug}/login")
    assert html =~ ~s(href="/s/#{store.slug}/whatsapp")
    refute html =~ ~s(href="/whatsapp")
  end

  test "themed home page: on the subdomain, theme links omit /s/:slug", %{
    conn: conn,
    store: store
  } do
    conn = Plug.Conn.put_private(conn, :emakola_on_store_subdomain?, true)
    {:ok, _v, html} = live(conn, "/s/#{store.slug}")
    assert html =~ ~s(href="/products")
    refute html =~ ~s(href="/s/#{store.slug}/products")
  end

  test "themed home page: on the apex, theme links keep /s/:slug", %{conn: conn, store: store} do
    {:ok, _v, html} = live(conn, "/s/#{store.slug}")
    assert html =~ ~s(href="/s/#{store.slug}/products")
  end

  test "footer contact/faq/policy links keep /s/:slug on the apex", %{conn: conn, store: store} do
    {:ok, _v, html} = live(conn, "/s/#{store.slug}/about")
    assert html =~ ~s(href="/s/#{store.slug}/contact")
    assert html =~ ~s(href="/s/#{store.slug}/faq")
    assert html =~ ~s(href="/s/#{store.slug}/policies#shipping")
  end

  test "footer contact/faq/policy links omit /s/:slug on the subdomain", %{
    conn: conn,
    store: store
  } do
    conn = Plug.Conn.put_private(conn, :emakola_on_store_subdomain?, true)
    {:ok, _v, html} = live(conn, "/s/#{store.slug}/about")
    assert html =~ ~s(href="/contact")
    assert html =~ ~s(href="/faq")
    assert html =~ ~s(href="/policies#shipping")
    refute html =~ ~s(href="/s/#{store.slug}/policies#shipping")
  end
end
