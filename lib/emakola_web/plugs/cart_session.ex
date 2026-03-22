defmodule EmakolaWeb.Plugs.CartSession do
  @moduledoc """
  Plug that ensures every request has a `cart_session_id` in the session.

  If one doesn't exist, a new UUID is generated and stored. This ID is used
  by `Emakola.Cart.CartStore` to persist cart items across page navigations
  and LiveView remounts.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case get_session(conn, "cart_session_id") do
      nil ->
        session_id = Ecto.UUID.generate()
        put_session(conn, "cart_session_id", session_id)

      _existing ->
        conn
    end
  end

  @doc """
  Extracts cart_session_id from the conn session for use in LiveView live_session.

  Used as: `session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []}`
  """
  def live_session_data(conn) do
    %{"cart_session_id" => get_session(conn, "cart_session_id")}
  end
end
