defmodule EmakolaWeb.SEO.CanonicalTest do
  @moduledoc """
  The single source of canonical/OG URLs (SEO Phase 0). Every URL is composed
  from the configured apex host and the `/@:slug/...` subfolder — never from a
  request host — so subdomains and custom domains can serve a page while
  canonical still points to one indexed URL.
  """
  use ExUnit.Case, async: true

  alias EmakolaWeb.SEO.Canonical

  setup do
    {:ok, base: EmakolaWeb.Endpoint.url(), store: %{slug: "kente-shop"}}
  end

  test "store_url uses the apex host + /@:slug subfolder", %{base: base, store: store} do
    assert Canonical.store_url(store) == base <> "/@kente-shop"
  end

  test "product_url", %{base: base, store: store} do
    assert Canonical.product_url(store, %{slug: "red-shoes"}) ==
             base <> "/@kente-shop/products/red-shoes"
  end

  test "category_url", %{base: base, store: store} do
    assert Canonical.category_url(store, %{slug: "footwear"}) ==
             base <> "/@kente-shop/category/footwear"
  end

  test "blog_url", %{base: base, store: store} do
    assert Canonical.blog_url(store, %{slug: "best-kente-2026"}) ==
             base <> "/@kente-shop/blog/best-kente-2026"
  end

  test "recipe_url", %{base: base, store: store} do
    assert Canonical.recipe_url(store, %{slug: "jollof"}) ==
             base <> "/@kente-shop/recipes/jollof"
  end

  test "page_url", %{base: base, store: store} do
    assert Canonical.page_url(store, %{slug: "about-us"}) ==
             base <> "/@kente-shop/p/about-us"
  end

  test "path/2 builds an arbitrary store-scoped canonical path", %{base: base, store: store} do
    assert Canonical.path(store, "/products") == base <> "/@kente-shop/products"
  end

  test "url/1 prefixes the apex to an absolute path", %{base: base} do
    assert Canonical.url("/sell-online/greater-accra") ==
             base <> "/sell-online/greater-accra"
  end
end
