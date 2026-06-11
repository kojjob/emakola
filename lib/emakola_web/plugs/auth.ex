defmodule EmakolaWeb.Plugs.Auth do
  @moduledoc "Loads current user from signed session token."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    token = get_session(conn, :user_token)

    with {:ok, subject} <- EmakolaWeb.AuthTokens.verify_subject(token),
         {:ok, user} <- AshAuthentication.subject_to_user(subject, Emakola.Accounts.User) do
      assign(conn, :current_user, user)
    else
      _ -> assign(conn, :current_user, nil)
    end
  end
end
