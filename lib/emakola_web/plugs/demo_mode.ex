defmodule EmakolaWeb.Plugs.DemoMode do
  @moduledoc "Blocks mutations in demo mode."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if Emakola.Demo.enabled?() and mutation_request?(conn) do
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(
        403,
        Jason.encode!(%{
          error: "demo_mode",
          message: "This action is disabled in demo mode."
        })
      )
      |> halt()
    else
      conn
    end
  end

  defp mutation_request?(conn) do
    conn.method in ["POST", "PUT", "PATCH", "DELETE"] and
      not safe_demo_path?(conn.request_path)
  end

  defp safe_demo_path?(path) do
    # Allow login/session creation in demo mode
    String.starts_with?(path, "/auth") or
      String.starts_with?(path, "/api/v1/session")
  end
end
