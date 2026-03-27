defmodule EmakolaWeb.Storefront.CustomerSessionController do
  @moduledoc """
  Handles customer session creation and destruction for storefront authentication.

  LiveView cannot set Plug session directly, so auth LiveViews redirect here
  to persist or clear the customer token in the session cookie.
  """
  use EmakolaWeb, :controller

  def create(conn, %{"store_slug" => slug, "token" => token}) do
    conn
    |> put_session(:customer_token, token)
    |> configure_session(renew: true)
    |> redirect(to: "/s/#{slug}/account")
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
end
