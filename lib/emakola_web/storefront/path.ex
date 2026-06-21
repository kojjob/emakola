defmodule EmakolaWeb.Storefront.Path do
  @moduledoc """
  Host-aware storefront link builder. On a store's own subdomain
  (`tiny-stitches.makola.io`) it drops the `/s/:slug` prefix so links read
  `/cart`; on the apex (`makola.io/s/:slug/...`) it keeps `/s/:slug/cart`.

  Use for the storefront's **navigational** links only. Canonical, sitemap and
  Open Graph URLs must keep using `EmakolaWeb.SEO.Canonical` (always apex
  `/s/:slug`) so SEO authority stays consolidated.

  `assigns` must carry `:on_store_subdomain?` (set by ResolveStore) and `:store`.
  """
  @spec store_path(map(), String.t()) :: String.t()
  def store_path(%{on_store_subdomain?: true}, subpath), do: normalize(subpath)

  def store_path(%{store: %{slug: slug}}, subpath) do
    case normalize(subpath) do
      "/" -> "/s/#{slug}"
      path -> "/s/#{slug}#{path}"
    end
  end

  defp normalize("/" <> _ = p), do: p
  defp normalize(""), do: "/"
  defp normalize(p), do: "/" <> p
end
