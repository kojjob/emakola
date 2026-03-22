defmodule EmakolaWeb.AuthSessionController do
  @moduledoc """
  Handles session creation and destruction for authentication.
  LiveView cannot set session directly, so auth forms redirect here
  to persist the user token in the session.
  """
  use EmakolaWeb, :controller

  def create(conn, %{"token" => token, "redirect_to" => redirect_to}) do
    conn
    |> put_session(:user_token, token)
    |> configure_session(renew: true)
    |> redirect(to: safe_redirect(redirect_to))
  end

  def create(conn, %{"token" => token}) do
    conn
    |> put_session(:user_token, token)
    |> configure_session(renew: true)
    |> redirect(to: "/dashboard")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/auth/login")
  end

  defp safe_redirect(path) do
    uri = URI.parse(path)

    if uri.host == nil and String.starts_with?(path, "/") do
      path
    else
      "/dashboard"
    end
  end
end
