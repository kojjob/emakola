defmodule EmakolaWeb.SEO.Canonical do
  @moduledoc """
  The single source of truth for canonical and Open Graph URLs.

  Platform/marketing URLs are composed from the configured apex host
  (`EmakolaWeb.Endpoint.url/0`, driven by `PHX_HOST`).

  A store's canonical origin is resolved best-first:

    1. its own live, **primary custom domain**, if it has one;
    2. its platform subdomain (`https://yourshop.makola.io/...`) when
       `:store_subdomain_base` is configured, so the store ranks as its own SEO
       entity (the Shopify model);
    3. the apex `/s/:slug/...` subfolder, in dev, tests, and pre-activation.

  Step 1 **reverses the Phase 0 stance** that all authority consolidates on the
  subfolder regardless of how the visitor arrived. That was right while branded
  hosts were cosmetic; it is wrong once a merchant pays for their own domain,
  because a shop on `kentekingdom.com` that self-identifies as `makola.io` in
  Google is the feature not working.

  The URL is still **never** composed from the request host — a store's
  canonical is a property of the store, not of how a given visitor reached it,
  so every entry point emits the same answer and authority stays consolidated
  on one origin.

  Only `type: :custom` domains can take step 1. Subdomain rows are marked
  `primary?` by the storefront-address panel, and honouring those would move
  every existing merchant's canonical to a vanity label.
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

  @doc """
  The sitemap a store's own robots.txt declares: `<origin>/sitemap.xml` on its
  custom domain or platform subdomain. The apex subfolder form has no
  `/:slug/sitemap.xml` route, so there it is the `/s/:slug/sitemap.xml` route.
  """
  def sitemap_url(%{slug: slug} = store) do
    case own_origin(store) do
      nil -> base() <> "/s/" <> slug <> "/sitemap.xml"
      origin -> origin <> "/sitemap.xml"
    end
  end

  # The SEO-primary origin for a store, best first:
  #
  #   1. its own live, primary custom domain — a merchant paying for
  #      kentekingdom.com and still seeing the platform host in Google is the
  #      feature not working;
  #   2. its platform subdomain, when a base is configured;
  #   3. the apex `/s/:slug` subfolder.
  #
  # Resolved here rather than threaded through call sites: exactly one caller
  # passes a bare `%{slug: slug}` map, and the other ~24 pass a `%Store{}`, so
  # keying on the slug leaves every one of them working unchanged. Canonical,
  # OG, JSON-LD and the sitemap all funnel through here, so they flip together.
  #
  # The scheme is taken from the endpoint (https in prod), and the port is
  # intentionally dropped — prod branded hosts are served on :443.
  defp store_base(%{slug: slug} = store), do: own_origin(store) || base() <> "/" <> slug

  # An origin that belongs to this store alone — its custom domain, else its
  # platform subdomain — or nil in the apex subfolder fallback. The fallback is
  # the short form, not `/s/:slug`: both route, but only one is a URL a merchant
  # can read down a phone line, and `ResolveStoreByHost` now 301s the `/s/` form
  # there anyway, so emitting it would just cost a hop.
  defp own_origin(%{slug: slug}) do
    case Emakola.Stores.DomainResolver.primary_host(slug) do
      host when is_binary(host) -> "#{scheme()}://#{host}"
      _ -> subdomain_origin(slug)
    end
  end

  defp subdomain_origin(slug) do
    case Application.get_env(:emakola, :store_subdomain_base) do
      sub_base when is_binary(sub_base) and sub_base != "" -> "#{scheme()}://#{slug}.#{sub_base}"
      _ -> nil
    end
  end

  defp scheme, do: URI.parse(EmakolaWeb.Endpoint.url()).scheme
end
