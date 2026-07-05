defmodule EmakolaWeb.Storefront.CustomerSessionController do
  @moduledoc """
  Handles customer session creation and destruction for storefront authentication.

  LiveView cannot set Plug session directly, so auth LiveViews redirect here
  to persist or clear the customer token in the session cookie.

  Tokens are Phoenix.Token-signed subjects (see `EmakolaWeb.AuthTokens`);
  the signature is verified before anything is written to the session.

  ## Routing

  Reachable two ways: apex `/s/:store_slug/auth/customer-session` (slug in the
  path) and the host-routed root `/auth/customer-session` on a store's own
  subdomain (store in `conn.assigns[:store]`, set by `ResolveStoreHost`).
  Redirect targets are built with `store_path/2` so they keep the `/s/:slug`
  prefix on the apex and drop it on the subdomain.
  """
  use EmakolaWeb, :controller

  import EmakolaWeb.Storefront.Path

  alias EmakolaWeb.AuthTokens

  def create(conn, %{"token" => token} = params) do
    # The URL carries a short-lived exchange token; mint the durable session
    # token here so the long-lived credential never appears in a URL.
    case AuthTokens.verify_subject_exchange(token) do
      {:ok, subject} ->
        conn
        |> put_session(:customer_token, AuthTokens.sign_subject(subject))
        |> configure_session(renew: true)
        |> redirect(to: store_path(store_slug(conn, params), "/account"))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid or expired sign-in link. Please log in again.")
        |> redirect(to: store_path(store_slug(conn, params), "/login"))
    end
  end

  def create(conn, params) do
    redirect(conn, to: store_path(store_slug(conn, params), "/login"))
  end

  def delete(conn, params) do
    conn
    |> delete_session(:customer_token)
    |> redirect(to: store_path(store_slug(conn, params), "/"))
  end

  def logout(conn, params) do
    conn
    |> delete_session(:customer_token)
    |> redirect(to: store_path(store_slug(conn, params), "/"))
  end

  # Store slug from the host-resolved assign (subdomain) or the path param
  # (apex). Sync the on-subdomain process flag from the session first so
  # `store_path/2` produces the root form on the subdomain.
  defp store_slug(conn, params) do
    put_on_store_subdomain(get_session(conn, :on_store_subdomain?) == true)

    case conn.assigns[:store] do
      %{slug: slug} -> slug
      _ -> params["store_slug"]
    end
  end
end
