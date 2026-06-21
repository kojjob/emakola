defmodule EmakolaWeb.Plugs.ResolveStoreByHost do
  @moduledoc """
  Resolves a branded host (`yourshop.makola.io`) to its store and, by default,
  301-redirects it to the canonical `/s/:slug` subfolder — consolidating SEO
  authority on one indexed URL (the Phase 0 strategy). A merchant can flip a
  `StoreDomain` to `serve_in_place?`, in which case this rewrites the request
  path to `/s/:slug/...` so the existing storefront routes render it on the
  branded host (canonical still points at the subfolder).

  Lives in the **endpoint** (before `plug Router`) rather than a router
  pipeline, because serve-in-place rewrites `conn.path_info` and the router
  matches on it — a pipeline plug would run after the route is already chosen.

  **Ships dark.** The subdomain base comes from `opts[:subdomain_base]` or
  `config :emakola, :store_subdomain_base` and defaults to `nil`, so the plug is
  a pure pass-through until the makola.io DNS + wildcard TLS cutover sets it.
  Static assets are served before this plug, so they're never redirected.
  """

  @behaviour Plug

  import Plug.Conn

  alias Emakola.Stores
  alias Emakola.Stores.Validations.ValidStoreHost

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

      {:serve_in_place, slug} ->
        # Stash in conn.private (not the session): this plug runs in the endpoint
        # BEFORE the router fetches the session, so put_session/3 would raise here.
        # The :browser pipeline's :put_store_subdomain_flag copies it to the session
        # after :fetch_session, where the storefront LiveView hook can read it.
        conn
        |> put_private(:emakola_on_store_subdomain?, true)
        |> rewrite_to_subfolder(slug)
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

  defp resolve_host(conn, base) do
    case Stores.get_store_domain_by_host(conn.host,
           load: [:store],
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, %{status: :active, serve_in_place?: true, store: %{slug: slug}}} ->
        {:serve_in_place, slug}

      {:ok, %{status: :active, store: %{slug: slug}}} ->
        {:redirect, EmakolaWeb.SEO.Canonical.store_url(%{slug: slug}) <> subpath(conn)}

      _ ->
        resolve_implicit_subdomain(conn.host, base)
    end
  end

  # No explicit StoreDomain row: a bare `<slug>.<base>` serves that store in place,
  # so every store gets its slug subdomain for free (no provisioning). Reserved
  # labels, multi-label hosts, and unknown slugs fall through to apex routing.
  defp resolve_implicit_subdomain(host, base) do
    suffix = "." <> base

    with true <- String.ends_with?(host, suffix),
         label = String.replace_suffix(host, suffix, ""),
         true <- valid_subdomain_label?(label) and not ValidStoreHost.reserved_label?(label),
         {:ok, _store} <- Stores.get_store_by_slug(label, authorize?: false) do
      {:serve_in_place, label}
    else
      _ -> :passthrough
    end
  end

  defp valid_subdomain_label?(label), do: label != "" and not String.contains?(label, ".")

  # The request path + query, mapped under /s/:slug. Root ("/") maps to the
  # bare store URL with no trailing slash.
  defp subpath(%{request_path: "/", query_string: ""}), do: ""
  defp subpath(%{request_path: "/", query_string: q}), do: "?" <> q
  defp subpath(%{request_path: path, query_string: ""}), do: path
  defp subpath(%{request_path: path, query_string: q}), do: path <> "?" <> q

  # Prepend ["s", slug] so the /s/:store_slug routes match — unless the path is
  # already a subfolder path (e.g. an internal link), which routes unchanged.
  defp rewrite_to_subfolder(%{path_info: ["s", slug | _]} = conn, slug), do: conn

  defp rewrite_to_subfolder(conn, slug) do
    %{conn | path_info: ["s", slug | conn.path_info]}
  end
end
