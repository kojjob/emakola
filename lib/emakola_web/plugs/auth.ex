defmodule EmakolaWeb.Plugs.Auth do
  @moduledoc "Loads current user from session token."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    token = get_session(conn, :user_token)

    if token do
      case AshAuthentication.subject_to_user(token, Emakola.Accounts.User) do
        {:ok, user} -> assign(conn, :current_user, user)
        _ -> assign(conn, :current_user, nil)
      end
    else
      assign(conn, :current_user, nil)
    end
  end
end
