defmodule EmakolaWeb.Plugs.ResolveStoreHost do
  @moduledoc """
  Storefront-pipeline plug that resolves the store from `conn.host` (the request
  subdomain) and stashes the slug in the session for the LiveView on_mount hook
  (`EmakolaWeb.Hooks.ResolveStoreFromHost`) to read.

  Host-based storefront routing serves the storefront at ROOT on a store's own
  subdomain (`kente-kingdom.makola.io/cart`), so the address-bar URL matches the
  mounted view and LiveView's client never force-reloads. The store can't be read
  from `socket.host_uri` (that's the CONFIGURED PHX_HOST, not the request
  subdomain), so it must be resolved here, after `:browser`'s `fetch_session`, and
  written to the session.

  Reuses the host→store logic from `ResolveStoreByHost`: an explicit active
  `StoreDomain` row, or the implicit `<slug>.<base>` match (guarded by
  `ValidStoreHost.reserved_label?/1`). On any failure — apex, reserved label, or
  unknown host — it redirects to `/` and halts (the apex has no store).

  Reads `:store_subdomain_base` at runtime so it tracks config changes.
  """

  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias Emakola.Stores
  alias Emakola.Stores.Validations.ValidStoreHost

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case resolve(conn.host, base()) do
      {:ok, slug, store} ->
        conn
        |> put_session(:store_host_slug, slug)
        |> put_session(:on_store_subdomain?, true)
        |> assign(:store, store)

      :error ->
        # Unknown/reserved/apex host with no store: redirect to the ABSOLUTE apex,
        # not a relative "/", which on a non-apex host would loop back through this
        # plug forever (the catch-all matches every non-apex host).
        conn
        |> redirect(external: EmakolaWeb.Endpoint.url() <> "/")
        |> halt()
    end
  end

  @doc """
  Resolves the store for a request `host` *without* touching the session — for
  controllers on the `:seo` pipeline (e.g. the sitemap), which doesn't
  `fetch_session`. Returns `{:ok, store}` or `:error`. Same host→store logic as
  the plug: an explicit StoreDomain row, then the implicit `<slug>.<base>` match.
  """
  def resolve_store(host) do
    case resolve(host, base()) do
      {:ok, _slug, store} -> {:ok, store}
      :error -> :error
    end
  end

  defp base, do: Application.get_env(:emakola, :store_subdomain_base)

  # An explicit, active StoreDomain row wins regardless of the subdomain base.
  # A merchant's own domain has nothing to do with the platform's subdomain
  # base, and gating on it here made custom domains unresolvable — and so
  # untestable — anywhere the base is unset, which is dev and test.
  defp resolve(host, base) do
    case Stores.get_store_domain_by_host(host,
           load: [:store],
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, %{status: :active, store: %{slug: slug} = store}} ->
        {:ok, slug, store}

      _ ->
        resolve_implicit_subdomain(host, base)
    end
  end

  # Only the IMPLICIT match needs a base: it is the platform's own namespace.
  defp resolve_implicit_subdomain(_host, nil), do: :error

  # No explicit StoreDomain row: a bare `<slug>.<base>` resolves to that store.
  # Reserved labels, multi-label hosts, and unknown slugs are rejected.
  defp resolve_implicit_subdomain(host, base) do
    suffix = "." <> base

    with true <- String.ends_with?(host, suffix),
         label = String.replace_suffix(host, suffix, ""),
         true <- valid_subdomain_label?(label) and not ValidStoreHost.reserved_label?(label),
         {:ok, store} <- Stores.get_store_by_slug(label, authorize?: false),
         false <- is_nil(store) do
      {:ok, label, store}
    else
      _ -> :error
    end
  end

  defp valid_subdomain_label?(label), do: label != "" and not String.contains?(label, ".")
end
