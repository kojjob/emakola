defmodule EmakolaWeb.Storefront.Path do
  @moduledoc """
  Host-aware storefront link builder. On a store's own subdomain
  (`tiny-stitches.makola.io`) it drops the `/s/:slug` prefix so links read
  `/cart`; on the apex (`makola.io/s/:slug/...`) it keeps `/s/:slug/cart`.

  Use for the storefront's **navigational** links only. Canonical, sitemap and
  Open Graph URLs must keep using `EmakolaWeb.SEO.Canonical` (always apex
  `/s/:slug`) so SEO authority stays consolidated.

  "Am I on this store's own subdomain?" is a request-scoped flag. Rather than
  thread it through every storefront component's attrs, `ResolveStore` stashes it
  in the process dictionary during `on_mount` and `store_path/2` reads it — the
  whole LiveView render runs in one process, the same pattern `Gettext` uses for
  the current locale. Pass the store slug at each call site.
  """
  @process_key :emakola_on_store_subdomain?

  @doc """
  Records, for the current render process, whether the request is being served on
  a store's own subdomain. Called once by `ResolveStore` in `on_mount`.
  """
  @spec put_on_store_subdomain(boolean()) :: term()
  def put_on_store_subdomain(flag) when is_boolean(flag), do: Process.put(@process_key, flag)

  @doc """
  Builds a storefront path for `subpath` under `slug`, dropping the `/s/:slug`
  prefix when the current render is on that store's own subdomain.
  """
  @spec store_path(String.t(), String.t()) :: String.t()
  def store_path(slug, subpath) when is_binary(slug) do
    if Process.get(@process_key, false) do
      normalize(subpath)
    else
      case normalize(subpath) do
        "/" -> "/s/#{slug}"
        path -> "/s/#{slug}#{path}"
      end
    end
  end

  defp normalize("/" <> _ = p), do: p
  defp normalize(""), do: "/"
  defp normalize(p), do: "/" <> p
end
