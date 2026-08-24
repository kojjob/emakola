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

  # The apex and its www form always route normally. Everything else is looked
  # up — including when no subdomain base is configured, because a merchant's
  # own domain has nothing to do with the platform's subdomain namespace.
  defp classify(%{host: host} = conn, base) do
    if base && (host == base or host == "www." <> base) do
      :passthrough
    else
      resolve_host(conn)
    end
  end

  defp resolve_host(conn) do
    case Stores.get_store_domain_by_host(conn.host,
           load: [:store],
           authorize?: false,
           not_found_error?: false
         ) do
      # An explicit, active, non-serve-in-place domain consolidates SEO on the
      # store's canonical origin. serve_in_place? domains, the implicit
      # <slug>.<base> match, and unknown hosts all pass through to the router.
      {:ok, %{status: :active, serve_in_place?: false, store: %{slug: slug}}} ->
        redirect_unless_self(conn, EmakolaWeb.SEO.Canonical.store_url(%{slug: slug}))

      _ ->
        :passthrough
    end
  end

  # Belt for the self-301 loop. A store's canonical can now BE a custom domain,
  # so a redirecting row could point at itself. `claim_custom` already forces
  # serve_in_place? on and SafePrimaryDomain refuses to turn it off, but this
  # holds regardless of any future drift in those invariants — and it is what
  # makes the automatic `www.` sibling safe: www.shop.com redirects to shop.com
  # (a different host, so it proceeds) while shop.com never redirects at all.
  defp redirect_unless_self(conn, target) do
    if URI.parse(target).host == conn.host do
      :passthrough
    else
      {:redirect, target <> subpath(conn)}
    end
  end

  # The request path + query, mapped under /s/:slug. Root ("/") maps to the
  # bare store URL with no trailing slash.
  defp subpath(%{request_path: "/", query_string: ""}), do: ""
  defp subpath(%{request_path: "/", query_string: q}), do: "?" <> q
  defp subpath(%{request_path: path, query_string: ""}), do: path
  defp subpath(%{request_path: path, query_string: q}), do: path <> "?" <> q
end
