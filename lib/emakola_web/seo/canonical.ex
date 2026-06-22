defmodule EmakolaWeb.SEO.Canonical do
  @moduledoc """
  The single source of truth for canonical and Open Graph URLs (SEO Phase 0).

  Platform/marketing URLs are composed from the configured apex host
  (`EmakolaWeb.Endpoint.url/0`, driven by `PHX_HOST`). Store-scoped URLs are
  **subdomain-primary** when `:store_subdomain_base` is configured: each store's
  canonical home is its own subdomain (`https://yourshop.makola.io/products/...`),
  so the store ranks as its own SEO entity (the Shopify model). When the base is
  unset (dev, tests, pre-activation) they fall back to the apex `/s/:slug/...`
  subfolder — gated on the same config as host routing, so canonical flips to
  subdomains exactly when subdomains go live.

  Either way the URL is composed from config — **never** from the request host —
  so the subdomain, the apex `/s/:slug` route, and a custom domain all emit the
  same canonical, consolidating authority onto one indexed URL per store instead
  of fragmenting it across hosts.

  Use these helpers in storefront LiveViews, the SEO component, the sitemap
  controller, and JSON-LD builders — anywhere a public URL is emitted.
  """

  @doc "Apex base, e.g. `https://makola.io` — platform/marketing pages."
  def base, do: EmakolaWeb.Endpoint.url()

  @doc "Prefix the apex to an already-absolute platform path."
  def url("/" <> _ = path), do: base() <> path

  @doc "A store-scoped canonical URL for an arbitrary sub-path (e.g. `\"/products\"`)."
  def path(%{slug: _} = store, "/" <> _ = subpath), do: store_base(store) <> subpath

  def store_url(%{slug: _} = store), do: store_base(store)
  def product_url(store, %{slug: slug}), do: path(store, "/products/" <> slug)
  def category_url(store, %{slug: slug}), do: path(store, "/category/" <> slug)
  def blog_url(store, %{slug: slug}), do: path(store, "/blog/" <> slug)
  def recipe_url(store, %{slug: slug}), do: path(store, "/recipes/" <> slug)
  def page_url(store, %{slug: slug}), do: path(store, "/p/" <> slug)

  # The SEO-primary origin for a store: its own subdomain when a base is
  # configured, else the apex `/s/:slug` subfolder. The scheme is taken from the
  # endpoint (https in prod), and the port is intentionally dropped — prod store
  # subdomains are served on the default :443 wildcard cert.
  defp store_base(%{slug: slug}) do
    case Application.get_env(:emakola, :store_subdomain_base) do
      sub_base when is_binary(sub_base) and sub_base != "" ->
        scheme = URI.parse(EmakolaWeb.Endpoint.url()).scheme
        "#{scheme}://#{slug}.#{sub_base}"

      _ ->
        base() <> "/s/" <> slug
    end
  end
end
