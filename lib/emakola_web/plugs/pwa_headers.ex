defmodule EmakolaWeb.Plugs.PWAHeaders do
  @moduledoc """
  Sets headers needed for Progressive Web App support.

  - `Service-Worker-Allowed: /` enables the service worker to control the entire origin.
  - Appropriate cache headers for `manifest.json` and `sw.js`.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> put_service_worker_allowed()
    |> set_pwa_cache_headers()
  end

  defp put_service_worker_allowed(conn) do
    put_resp_header(conn, "service-worker-allowed", "/")
  end

  defp set_pwa_cache_headers(conn) do
    case conn.request_path do
      "/manifest.json" ->
        put_resp_header(conn, "cache-control", "public, max-age=86400")

      "/sw.js" ->
        # Service workers should not be cached for long so updates propagate
        put_resp_header(conn, "cache-control", "public, max-age=0, must-revalidate")

      _ ->
        conn
    end
  end
end
