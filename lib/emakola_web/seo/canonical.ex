defmodule EmakolaWeb.SEO.Canonical do
  @moduledoc """
  The single source of truth for canonical and Open Graph URLs (SEO Phase 0).

  Every URL is composed from the configured apex host (`EmakolaWeb.Endpoint.url/0`,
  driven by `PHX_HOST`) and the `/s/:slug/...` subfolder form — deliberately
  **never** from the request host. This is the load-bearing decision that lets a
  subdomain (`yourshop.emakola.io`) or custom domain (`yourshop.com`) serve a page
  while `rel=canonical`/`og:url` still point to one indexed URL on the apex, so
  marketplace authority consolidates instead of fragmenting.

  Use these helpers in storefront LiveViews, the SEO component, the sitemap
  controller, and JSON-LD builders — anywhere a public URL is emitted.
  """

  @doc "Apex base, e.g. `https://emakola.io`."
  def base, do: EmakolaWeb.Endpoint.url()

  @doc "Prefix the apex to an already-absolute path."
  def url("/" <> _ = path), do: base() <> path

  @doc "A store-scoped canonical URL for an arbitrary sub-path (e.g. `\"/products\"`)."
  def path(%{slug: slug}, "/" <> _ = subpath), do: base() <> "/@" <> slug <> subpath

  def store_url(%{slug: slug}), do: base() <> "/@" <> slug
  def product_url(store, %{slug: slug}), do: path(store, "/products/" <> slug)
  def category_url(store, %{slug: slug}), do: path(store, "/category/" <> slug)
  def blog_url(store, %{slug: slug}), do: path(store, "/blog/" <> slug)
  def recipe_url(store, %{slug: slug}), do: path(store, "/recipes/" <> slug)
  def page_url(store, %{slug: slug}), do: path(store, "/p/" <> slug)
end
