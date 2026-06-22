defmodule EmakolaWeb.Plugs.ResolveStoreByHost do
  @moduledoc """
  301-redirects an explicit, active, **non**-serve-in-place branded `StoreDomain`
  host (e.g. a custom domain `shop.example.com`) to its canonical `/s/:slug`
  subfolder — consolidating SEO authority on one indexed URL (the Phase 0
  strategy).

  Everything else passes through to the router, which host-routes the storefront
  at root (`EmakolaWeb.Plugs.ResolveStoreHost` + the storefront catch-all): store
  subdomains (`yourshop.makola.io`, explicit serve-in-place domains, and the
  implicit `<slug>.<base>` match) all render at root so the address-bar URL
  matches the mounted LiveView. Unknown/reserved hosts pass through too — the
  catch-all's `ResolveStoreHost` redirects them to the apex `/`.

  Lives in the **endpoint** (before `plug Router`); the redirect must happen
  before any route is chosen.

  **Ships dark.** The subdomain base comes from `opts[:subdomain_base]` or
  `config :emakola, :store_subdomain_base` and defaults to `nil`, so the plug is
  a pure pass-through until the makola.io DNS + wildcard TLS cutover sets it.
  Static assets are served before this plug, so they're never redirected.
  """

  @behaviour Plug

  import Plug.Conn

  alias Emakola.Stores

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    case classify(conn, base(opts)) do
      :passthrough ->
        conn

      {:redirect, target} ->
        conn
        |> put_resp_header("location", target)
        |> send_resp(301, "")
        |> halt()
    end
  end

  defp base(opts),
    do: opts[:subdomain_base] || Application.get_env(:emakola, :store_subdomain_base)

  # nil base → ship-dark; apex/www → normal apex routing; otherwise look it up.
  defp classify(_conn, nil), do: :passthrough

  defp classify(%{host: host} = conn, base) do
    if host == base or host == "www." <> base do
      :passthrough
    else
      resolve_host(conn, base)
    end
  end

  defp resolve_host(conn, _base) do
    case Stores.get_store_domain_by_host(conn.host,
           load: [:store],
           authorize?: false,
           not_found_error?: false
         ) do
      # An explicit, active, non-serve-in-place domain consolidates SEO on the
      # /s/:slug subfolder. serve_in_place? domains, the implicit <slug>.<base>
      # match, and unknown/reserved hosts all pass through to the router.
      {:ok, %{status: :active, serve_in_place?: false, store: %{slug: slug}}} ->
        {:redirect, EmakolaWeb.SEO.Canonical.store_url(%{slug: slug}) <> subpath(conn)}

      _ ->
        :passthrough
    end
  end

  # The request path + query, mapped under /s/:slug. Root ("/") maps to the
  # bare store URL with no trailing slash.
  defp subpath(%{request_path: "/", query_string: ""}), do: ""
  defp subpath(%{request_path: "/", query_string: q}), do: "?" <> q
  defp subpath(%{request_path: path, query_string: ""}), do: path
  defp subpath(%{request_path: path, query_string: q}), do: path <> "?" <> q
end
