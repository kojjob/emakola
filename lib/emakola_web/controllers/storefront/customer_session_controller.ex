defmodule EmakolaWeb.Storefront.CustomerSessionController do
  @moduledoc """
  Handles customer session creation and destruction for storefront authentication.

  LiveView cannot set Plug session directly, so auth LiveViews redirect here
  to persist or clear the customer token in the session cookie.

  Tokens are Phoenix.Token-signed subjects (see `EmakolaWeb.AuthTokens`);
  the signature is verified before anything is written to the session.
  """
  use EmakolaWeb, :controller

  alias EmakolaWeb.AuthTokens

  def create(conn, %{"store_slug" => slug, "token" => token}) do
    case AuthTokens.verify_subject(token) do
      {:ok, _subject} ->
        conn
        |> put_session(:customer_token, token)
        |> configure_session(renew: true)
        |> redirect(to: "/s/#{slug}/account")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid or expired sign-in link. Please log in again.")
        |> redirect(to: "/s/#{slug}/login")
    end
  end

  def create(conn, %{"store_slug" => slug}) do
    conn
    |> redirect(to: "/s/#{slug}/login")
  end

  def delete(conn, %{"store_slug" => slug}) do
    conn
    |> delete_session(:customer_token)
    |> redirect(to: "/s/#{slug}")
  end

  def logout(conn, %{"store_slug" => slug}) do
    conn
    |> delete_session(:customer_token)
    |> redirect(to: "/s/#{slug}")
  end
end
