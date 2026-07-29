defmodule EmakolaWeb.ClientIp do
  @moduledoc """
  Resolves the real client IP for a LiveView socket.

  HTTP requests get this for free: `plug RemoteIp` in the endpoint walks
  `X-Forwarded-For` into `conn.remote_ip` before anything keys on it. LiveView
  sockets do not go through that plug — `get_connect_info(socket, :peer_data)`
  returns the *direct* peer, which behind the Fly proxy is an internal 6PN
  address shared by every visitor.

  Rate limiters keyed on that address put all users in one bucket: ten
  password-reset attempts would lock out everyone behind the proxy for the
  rest of the window. Resolve `:x_headers` the same way `RemoteIp` does, and
  fall back to the peer only when no forwarded headers are present (local dev).
  """

  @doc "Returns the client IP as a string, or `\"unknown\"` if undeterminable."
  @spec resolve(Phoenix.LiveView.Socket.t()) :: String.t()
  def resolve(socket) do
    with headers when is_list(headers) and headers != [] <-
           Phoenix.LiveView.get_connect_info(socket, :x_headers),
         ip when not is_nil(ip) <- RemoteIp.from(headers) do
      to_string(:inet.ntoa(ip))
    else
      _ -> peer_ip(socket)
    end
  rescue
    _ -> "unknown"
  end

  defp peer_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: {a, b, c, d}} -> "#{a}.#{b}.#{c}.#{d}"
      %{address: ip} -> to_string(:inet.ntoa(ip))
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end
end
