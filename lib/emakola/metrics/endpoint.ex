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

  # sobelow_skip ["XSS.SendResp"]
  # False positive: the body is Prometheus exposition text built solely from
  # internal metric names — no user input — served as text/plain (browsers
  # never execute it) on a private listener that isn't the public endpoint.
  @impl true
  def call(%{method: "GET", request_path: "/metrics"} = conn, _opts) do
    conn
    |> put_resp_header("content-type", "text/plain; version=0.0.4; charset=utf-8")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, Emakola.Metrics.Prometheus.render())
  end

  def call(conn, _opts), do: send_resp(conn, 404, "not found")
end
