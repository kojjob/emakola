defmodule EmakolaWeb.SEO.CanonicalTest do
  @moduledoc """
  The single source of canonical/OG URLs (SEO Phase 0).

  Store-scoped URLs are **subdomain-primary** when `:store_subdomain_base` is
  configured (`https://<slug>.<base>/...` — the SEO-primary host once subdomain
  routing is live), and fall back to the apex `/s/:slug/...` subfolder when it is
  not (dev, tests, pre-activation). Either way the URL is composed from config —
  never from the request host — so every host that serves a page emits the same
  canonical, consolidating authority onto one indexed URL per store.
  """
  use ExUnit.Case, async: false

  alias EmakolaWeb.SEO.Canonical

  describe "apex subfolder form (default — no :store_subdomain_base)" do
    setup do
      previous = Application.get_env(:emakola, :store_subdomain_base)
      Application.delete_env(:emakola, :store_subdomain_base)

      on_exit(fn ->
        if previous, do: Application.put_env(:emakola, :store_subdomain_base, previous)
      end)

      {:ok, base: EmakolaWeb.Endpoint.url(), store: %{slug: "kente-shop"}}
    end

    test "store_url uses the apex host + /s/:slug subfolder", %{base: base, store: store} do
      assert Canonical.store_url(store) == base <> "/s/kente-shop"
    end

    test "product_url", %{base: base, store: store} do
      assert Canonical.product_url(store, %{slug: "red-shoes"}) ==
               base <> "/s/kente-shop/products/red-shoes"
    end

    test "category_url", %{base: base, store: store} do
      assert Canonical.category_url(store, %{slug: "footwear"}) ==
               base <> "/s/kente-shop/category/footwear"
    end

    test "blog_url", %{base: base, store: store} do
      assert Canonical.blog_url(store, %{slug: "best-kente-2026"}) ==
               base <> "/s/kente-shop/blog/best-kente-2026"
    end

    test "recipe_url", %{base: base, store: store} do
      assert Canonical.recipe_url(store, %{slug: "jollof"}) ==
               base <> "/s/kente-shop/recipes/jollof"
    end

    test "page_url", %{base: base, store: store} do
      assert Canonical.page_url(store, %{slug: "about-us"}) ==
               base <> "/s/kente-shop/p/about-us"
    end

    test "path/2 builds an arbitrary store-scoped canonical path", %{base: base, store: store} do
      assert Canonical.path(store, "/products") == base <> "/s/kente-shop/products"
    end

    test "url/1 prefixes the apex to an absolute path", %{base: base} do
      assert Canonical.url("/sell-online/greater-accra") ==
               base <> "/sell-online/greater-accra"
    end
  end

  describe "store subdomain form (:store_subdomain_base configured)" do
    setup do
      previous = Application.get_env(:emakola, :store_subdomain_base)
      Application.put_env(:emakola, :store_subdomain_base, "makola.io")

      on_exit(fn ->
        if previous,
          do: Application.put_env(:emakola, :store_subdomain_base, previous),
          else: Application.delete_env(:emakola, :store_subdomain_base)
      end)

      scheme = URI.parse(EmakolaWeb.Endpoint.url()).scheme
      {:ok, origin: "#{scheme}://kente-shop.makola.io", store: %{slug: "kente-shop"}}
    end

    test "store_url is the store's own subdomain root", %{origin: origin, store: store} do
      assert Canonical.store_url(store) == origin
    end

    test "product_url is subdomain-rooted (drops the /s/:slug prefix)", %{
      origin: origin,
      store: store
    } do
      assert Canonical.product_url(store, %{slug: "red-shoes"}) == origin <> "/products/red-shoes"
    end

    test "category_url", %{origin: origin, store: store} do
      assert Canonical.category_url(store, %{slug: "footwear"}) == origin <> "/category/footwear"
    end

    test "blog_url", %{origin: origin, store: store} do
      assert Canonical.blog_url(store, %{slug: "best-kente-2026"}) ==
               origin <> "/blog/best-kente-2026"
    end

    test "recipe_url", %{origin: origin, store: store} do
      assert Canonical.recipe_url(store, %{slug: "jollof"}) == origin <> "/recipes/jollof"
    end

    test "page_url", %{origin: origin, store: store} do
      assert Canonical.page_url(store, %{slug: "about-us"}) == origin <> "/p/about-us"
    end

    test "path/2 is rooted at the subdomain", %{origin: origin, store: store} do
      assert Canonical.path(store, "/products") == origin <> "/products"
    end

    test "url/1 (platform path) stays on the apex even when a subdomain base is set" do
      assert Canonical.url("/sell-online/greater-accra") ==
               EmakolaWeb.Endpoint.url() <> "/sell-online/greater-accra"
    end
  end
end
