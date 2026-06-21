defmodule EmakolaWeb.AuthController do
  @moduledoc """
  Bridges ash_authentication's OAuth request/callback flow into the app's
  existing cookie session.

  After a provider (Google/Facebook/Apple) authenticates a merchant,
  `success/4` signs the very same subject the password and magic-link flows
  use (`EmakolaWeb.AuthTokens.sign_subject/1`), stores it under `:user_token`,
  and lands on the merchant dashboard — so OAuth reuses the established session
  rather than introducing a parallel one.
  """
  use EmakolaWeb, :controller
  use AshAuthentication.Phoenix.Controller

  require Logger

  alias EmakolaWeb.AuthTokens

  def success(conn, _activity, %Emakola.Accounts.Merchant{} = merchant, _token) do
    subject_token = AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn
    |> put_session(:user_token, subject_token)
    |> configure_session(renew: true)
    |> redirect(to: "/dashboard")
  end

  def success(conn, _activity, %Emakola.Customers.Customer{} = customer, _token) do
    subject_token = AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
    slug = EmakolaWeb.Plugs.CustomerOAuthTenant.store_slug(conn)

    conn
    |> put_session(:customer_token, subject_token)
    |> configure_session(renew: true)
    |> redirect(to: customer_landing(slug))
  end

  def failure(conn, activity, reason) do
    Logger.warning("[oauth] sign-in failed for #{inspect(activity)}: #{inspect(reason)}")

    conn
    |> put_flash(:error, "Sign-in with that provider didn't work. Please try again.")
    |> redirect(to: "/auth/login")
  end

  def sign_out(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/auth/login")
  end

  defp customer_landing(nil), do: "/"
  defp customer_landing(slug), do: "/s/#{slug}/account"
end
