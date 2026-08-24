defmodule EmakolaWeb.Storefront.Path do
  @moduledoc """
  Storefront link builder. A store is reachable three ways, and each page links
  in the same dialect it was reached by, so a visitor's URL shape never changes
  underneath them mid-visit:

    * `:branded`   — the store's own subdomain or custom domain. Links are bare
      (`/cart`), because the host already identifies the store.
    * `:short`     — `makola.io/yourshop`. Links carry the slug (`/yourshop/cart`).
    * `:subfolder` — `makola.io/s/yourshop`. The original form, still routed so
      links shared before short URLs existed keep working.

  Use for the storefront's **navigational** links only. Canonical, sitemap and
  Open Graph URLs go through `EmakolaWeb.SEO.Canonical`, which answers with the
  store's one true origin regardless of how this visitor arrived — that is what
  keeps three entry points from fragmenting SEO into three.

  The mode is request-scoped. Rather than thread it through every storefront
  component's attrs, `ResolveStore` stashes it in the process dictionary during
  `on_mount` and `store_path/2` reads it — the whole LiveView render runs in one
  process, the same pattern `Gettext` uses for the current locale.
  """
  @process_key :emakola_storefront_path_mode

  @type mode :: :branded | :short | :subfolder

  @doc """
  Records which URL form the current render was reached by. Called once by
  `ResolveStore` / `ResolveStoreFromHost` in `on_mount`.
  """
  @spec put_mode(mode()) :: term()
  def put_mode(mode) when mode in [:branded, :short, :subfolder],
    do: Process.put(@process_key, mode)

  @doc """
  Boolean form kept for the branded-host callers that predate short URLs.
  """
  @spec put_on_store_subdomain(boolean()) :: term()
  def put_on_store_subdomain(true), do: put_mode(:branded)
  def put_on_store_subdomain(false), do: put_mode(:subfolder)

  @doc """
  Builds a storefront path for `subpath` under `slug`, in whichever form the
  current render was reached by. Every page links in its own dialect, so a
  visitor's URL shape never changes underneath them mid-visit.
  """
  @spec store_path(String.t(), String.t()) :: String.t()
  def store_path(slug, subpath) when is_binary(slug) do
    case mode() do
      :branded -> normalize(subpath)
      :short -> prefixed("/#{slug}", subpath)
      _subfolder -> prefixed("/s/#{slug}", subpath)
    end
  end

  defp prefixed(prefix, subpath) do
    case normalize(subpath) do
      "/" -> prefix
      path -> prefix <> path
    end
  end

  defp mode, do: Process.get(@process_key, :subfolder)

  defp normalize("/" <> _ = p), do: p
  defp normalize(""), do: "/"
  defp normalize(p), do: "/" <> p
end
