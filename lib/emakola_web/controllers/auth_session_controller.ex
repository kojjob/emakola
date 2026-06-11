defmodule EmakolaWeb.AuthSessionController do
  @moduledoc """
  Handles session creation and destruction for authentication.
  LiveView cannot set session directly, so auth forms redirect here
  to persist the user token in the session.

  Tokens are Phoenix.Token-signed subjects (see `EmakolaWeb.AuthTokens`);
  the signature is verified before anything is written to the session.
  """
  use EmakolaWeb, :controller

  alias EmakolaWeb.AuthTokens

  def create(conn, %{"token" => token} = params) do
    case AuthTokens.verify_subject(token) do
      {:ok, _subject} ->
        conn
        |> put_session(:user_token, token)
        |> configure_session(renew: true)
        |> redirect(to: safe_redirect(params["redirect_to"]))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid or expired sign-in link. Please log in again.")
        |> redirect(to: "/auth/login")
    end
  end

  # Fallback: GET /auth/session with no token — redirect to login
  def create(conn, _params) do
    conn
    |> redirect(to: "/auth/login")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/auth/login")
  end

  defp safe_redirect(nil), do: "/dashboard"

  defp safe_redirect(path) do
    uri = URI.parse(path)

    if uri.host == nil and String.starts_with?(path, "/") do
      path
    else
      "/dashboard"
    end
  end
end
