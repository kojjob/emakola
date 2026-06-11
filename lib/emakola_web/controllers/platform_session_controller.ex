defmodule EmakolaWeb.PlatformSessionController do
  @moduledoc """
  Exchanges a short-lived signed login token for a DB-backed platform
  session, and handles platform logout.

  LiveView cannot write the session cookie, so the login flow redirects
  here with a 30-second exchange token (`EmakolaWeb.AuthTokens`). The
  controller re-verifies active staff status, creates the session row
  with the real connection ip/user-agent, and stores the signed session
  id under `:platform_session_token`.
  """
  use EmakolaWeb, :controller

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Accounts.Sessions
  alias EmakolaWeb.AuthTokens

  def create(conn, %{"t" => exchange_token}) do
    with {:ok, user_id} <- AuthTokens.verify_login_exchange(exchange_token),
         {:ok, user} <- Emakola.Accounts.get_user_by_id(user_id, authorize?: false),
         true <- PlatformPermissions.staff?(user),
         {:ok, session} <- Sessions.create(user, ip(conn), user_agent(conn)) do
      PlatformAudit.log(:sign_in_succeeded, user, %{}, ip(conn))

      conn
      |> put_session(:platform_session_token, AuthTokens.sign_platform_session(session.id))
      |> put_session(:live_socket_id, Sessions.live_socket_id(session.id))
      |> configure_session(renew: true)
      |> redirect(to: "/platform")
    else
      _ -> reject(conn)
    end
  end

  def create(conn, _params), do: reject(conn)

  def delete(conn, _params) do
    with {:ok, session_id} <-
           AuthTokens.verify_platform_session(get_session(conn, :platform_session_token)),
         {:ok, session} <- Sessions.revoke(session_id) do
      PlatformAudit.log(:sign_out, session.user_id, %{session_id: session.id}, ip(conn))
    end

    conn
    # delete_session (not configure_session(drop: true)) so a coexisting
    # merchant :user_token session survives platform logout.
    |> delete_session(:platform_session_token)
    |> delete_session(:live_socket_id)
    |> redirect(to: "/platform/login")
  end

  defp reject(conn) do
    conn
    |> put_flash(:error, "Sign-in failed. Please log in again.")
    |> redirect(to: "/platform/login")
  end

  defp ip(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()

  defp user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> String.slice(ua, 0, 500)
      _ -> nil
    end
  end
end
