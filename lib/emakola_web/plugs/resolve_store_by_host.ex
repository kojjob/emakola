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
  alias Emakola.Stores.DomainResolver
  alias EmakolaWeb.ReservedStoreSlugs

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
      apex_move(conn)
    else
      resolve_host(conn)
    end
  end

  # On the apex, a store reached by its subfolder (or short) URL is moved to
  # its own domain the same way its subdomain is. Canonical alone is a hint
  # Google may take slowly; a 301 is the definitive signal for a domain move
  # and is what carries ranking across.
  defp apex_move(conn) do
    case apex_store_slug(conn) do
      nil ->
        :passthrough

      {slug, rest} ->
        case DomainResolver.primary_host(slug) do
          host when is_binary(host) -> {:redirect, origin(host) <> rest <> query(conn)}
          _ -> short_move(conn, slug, rest)
        end
    end
  end

  # No custom domain, but the store still should not live behind `/s/`. Move it
  # to the short form so one URL shape is the only one anyone sees or shares.
  #
  # Only moved when the short form actually routes. `/s/:slug/sitemap.xml`,
  # the customer auth callbacks and the product feeds have no short route, and
  # 301-ing them would turn a working URL into a 404 that browsers then cache.
  # Asking the router keeps this honest: add a short route later and it starts
  # being covered, with nothing here to remember to update.
  defp short_move(conn, slug, rest) do
    target = "/" <> slug <> rest

    if ReservedStoreSlugs.reserved?(slug) or not routed?(conn, target) do
      :passthrough
    else
      {:redirect, target <> query(conn)}
    end
  end

  defp routed?(conn, path) do
    match?(%{}, Phoenix.Router.route_info(EmakolaWeb.Router, conn.method, path, conn.host))
  end

  # Only "/s/:slug/rest" identifies a store by path on the apex; everything else
  # is a platform page and is never touched.
  #
  # The short form (makola.io/:slug) needs the same move, but that route — and
  # the reserved-slug list that tells a store slug apart from a platform page —
  # arrive with the short-URL work. Extending this to `[slug | rest]` without
  # that list would 301 the pricing page to a merchant's domain.
  defp apex_store_slug(%{path_info: ["s", slug | rest]}), do: {slug, join(rest)}
  defp apex_store_slug(_conn), do: nil

  defp join([]), do: ""
  defp join(segments), do: "/" <> Enum.join(segments, "/")

  defp query_suffix(%{query_string: ""}), do: ""
  defp query_suffix(%{query_string: q}), do: "?" <> q

  defp origin(host) do
    scheme = URI.parse(EmakolaWeb.Endpoint.url()).scheme
    "#{scheme}://#{host}"
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
        implicit_subdomain_move(conn)
    end
  end

  # A store subdomain is served implicitly, with no StoreDomain row, so it
  # never reaches the branch above. It still has to move once the store has a
  # domain of its own.
  defp implicit_subdomain_move(conn) do
    with base when is_binary(base) <- base([]),
         suffix = "." <> base,
         true <- String.ends_with?(conn.host, suffix),
         slug = String.replace_suffix(conn.host, suffix, ""),
         host when is_binary(host) <- DomainResolver.primary_host(slug) do
      redirect_unless_self(conn, origin(host))
    else
      _ -> :passthrough
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
