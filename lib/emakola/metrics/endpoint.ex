defmodule Emakola.Metrics.Endpoint do
  @moduledoc """
  Private Plug served by a dedicated Bandit listener for Fly's scraper.

  The listener is intentionally separate from the public Phoenix endpoint, so
  operational metrics are not exposed through the customer-facing HTTP
  service.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "GET", request_path: "/metrics"} = conn, _opts) do
    conn
    |> put_resp_header("content-type", "text/plain; version=0.0.4; charset=utf-8")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, Emakola.Metrics.Prometheus.render())
  end

  def call(conn, _opts), do: send_resp(conn, 404, "not found")
end
