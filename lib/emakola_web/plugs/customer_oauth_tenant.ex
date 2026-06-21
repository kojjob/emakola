defmodule EmakolaWeb.Plugs.CustomerOAuthTenant do
  @moduledoc """
  Carries the store across the storefront OAuth round-trip.

  The OAuth callback is a fixed path (`/oauth/customer/<provider>/callback`)
  registered once per provider, so the store can't live in the URL — it rides
  in the session:

    * **Request** (`?store_slug=...`): resolve the store, stash it in the
      session, and set the Ash tenant so `register_with_oauth2` upserts the
      customer in the right store.
    * **Callback**: read the store from the session and set the tenant again
      (the provider sends the user back with the same session cookie).

  No-op for non-customer OAuth routes (e.g. `/oauth/merchant/*`), so it can sit
  in the shared `/oauth` pipeline harmlessly.
  """
  import Plug.Conn

  @store_id_key "customer_oauth_store_id"
  @store_slug_key "customer_oauth_store_slug"

  def init(opts), do: opts

  def call(conn, _opts) do
    if customer_oauth_route?(conn) do
      conn |> stash_store() |> apply_tenant()
    else
      conn
    end
  end

  @doc "Store slug stashed during the OAuth request — for the callback redirect."
  def store_slug(conn), do: get_session(conn, @store_slug_key)

  defp customer_oauth_route?(conn), do: match?(["oauth", "customer" | _], conn.path_info)

  # Request phase: the button passes ?store_slug=…; resolve + stash for the callback.
  defp stash_store(%{params: %{"store_slug" => slug}} = conn) when is_binary(slug) do
    case Emakola.Stores.get_store_by_slug(String.trim_leading(slug, "@"), authorize?: false) do
      {:ok, store} ->
        conn
        |> put_session(@store_id_key, store.id)
        |> put_session(@store_slug_key, store.slug)

      _ ->
        conn
    end
  end

  defp stash_store(conn), do: conn

  defp apply_tenant(conn) do
    case get_session(conn, @store_id_key) do
      nil -> conn
      store_id -> Ash.PlugHelpers.set_tenant(conn, store_id)
    end
  end
end
