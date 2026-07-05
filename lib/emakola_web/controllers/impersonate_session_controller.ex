defmodule EmakolaWeb.ImpersonateSessionController do
  @moduledoc """
  Platform-staff "log in as merchant" — start and exit.

  Session bridging needs a controller (LiveView can't write the session cookie).
  `start` verifies the real staff (active platform session + `:manage_merchants`),
  then swaps the cookie: it stashes the staff `UserSession` id, drops the
  `:platform_session_token`, and sets `:user_token` (the impersonated merchant's
  signed subject) plus an `:impersonation` map (staff id, merchant id, a 30-min
  `expires_at`, the return session id). `exit` re-signs the platform token from
  the stashed id (the staff session was never revoked) and clears the keys.

  Both decisions are written to the platform audit log. `AssignDefaults` reads
  `:impersonation` to surface the real staff as `impersonator` (for the banner)
  and to auto-exit once the window elapses.
  """
  use EmakolaWeb, :controller

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Accounts.Sessions
  alias EmakolaWeb.AuthTokens

  @window_seconds 30 * 60

  def start(conn, %{"merchant_id" => merchant_id}) do
    with {:ok, staff, staff_session} <- current_staff(conn),
         {:ok, %{} = merchant} <- Emakola.Accounts.get_merchant(merchant_id, authorize?: false) do
      token = AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      PlatformAudit.log(
        :impersonation_started,
        staff,
        %{
          "merchant_id" => merchant.id,
          "merchant_email" => merchant.email,
          "merchant_name" => merchant.name
        },
        ip(conn)
      )

      conn
      # Drop the staff token so the merchant `:user_token` resolves; the staff
      # UserSession row is kept (not revoked) and restored on exit.
      |> delete_session(:platform_session_token)
      |> delete_session(:live_socket_id)
      |> put_session(:user_token, token)
      |> put_session(:impersonation, %{
        "staff_user_id" => staff.id,
        "merchant_id" => merchant.id,
        "expires_at" => System.os_time(:second) + @window_seconds,
        "return_session_id" => staff_session.id
      })
      |> configure_session(renew: true)
      |> redirect(to: "/dashboard")
    else
      _ -> reject(conn)
    end
  end

  def start(conn, _params), do: reject(conn)

  def exit(conn, _params) do
    case get_session(conn, :impersonation) do
      %{"return_session_id" => return_session_id} = impersonation ->
        PlatformAudit.log(
          :impersonation_ended,
          impersonation["staff_user_id"],
          %{"merchant_id" => impersonation["merchant_id"]},
          ip(conn)
        )

        conn
        |> delete_session(:user_token)
        |> delete_session(:impersonation)
        |> put_session(
          :platform_session_token,
          AuthTokens.sign_platform_session(return_session_id)
        )
        |> put_session(:live_socket_id, Sessions.live_socket_id(return_session_id))
        |> configure_session(renew: true)
        |> redirect(to: "/platform")

      _ ->
        redirect(conn, to: "/platform")
    end
  end

  defp current_staff(conn) do
    with {:ok, session_id} <-
           AuthTokens.verify_platform_session(get_session(conn, :platform_session_token)),
         {:ok, user, session} <- Sessions.verify_session_id(session_id),
         true <- PlatformPermissions.allowed?(user, :manage_merchants) do
      {:ok, user, session}
    else
      _ -> :error
    end
  end

  defp reject(conn) do
    conn
    |> put_flash(:error, "Could not start impersonation.")
    |> redirect(to: "/platform")
  end

  defp ip(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
end
