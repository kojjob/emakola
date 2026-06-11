defmodule EmakolaWeb.Plugs.Auth do
  @moduledoc """
  Loads the current user from the session.

  Resolution order:
  1. `:platform_session_token` — signed DB-backed platform-staff session
     (assigns `:current_user` and `:current_session_id`)
  2. `:user_token` — signed AshAuthentication subject (legacy User flow)

  Not currently mounted in the router — updated and kept for the
  platform-admin auth hardening plan.
  """
  import Plug.Conn

  alias Emakola.Accounts.Sessions
  alias EmakolaWeb.AuthTokens

  def init(opts), do: opts

  def call(conn, _opts) do
    case platform_session(conn) do
      {:ok, user, session} ->
        conn
        |> assign(:current_user, user)
        |> assign(:current_session_id, session.id)

      :error ->
        resolve_user_token(conn)
    end
  end

  defp platform_session(conn) do
    with {:ok, session_id} <-
           AuthTokens.verify_platform_session(get_session(conn, :platform_session_token)),
         {:ok, user, session} <- Sessions.verify_session_id(session_id) do
      {:ok, user, session}
    else
      _ -> :error
    end
  end

  defp resolve_user_token(conn) do
    token = get_session(conn, :user_token)

    with {:ok, subject} <- AuthTokens.verify_subject(token),
         {:ok, user} <- AshAuthentication.subject_to_user(subject, Emakola.Accounts.User) do
      assign(conn, :current_user, user)
    else
      _ -> assign(conn, :current_user, nil)
    end
  end
end
