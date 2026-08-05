defmodule Emakola.Metrics.EndpointTest do
  @moduledoc false

  use Emakola.DataCase, async: false

  import Plug.Conn
  import Plug.Test

  alias Emakola.Metrics.Endpoint

  test "GET /metrics returns a Prometheus exposition without caching" do
    conn = Endpoint.call(conn(:get, "/metrics"), [])

    assert conn.status == 200
    assert conn.resp_body =~ "emakola_up 1"
    assert conn.resp_body =~ "emakola_database_up 1"
    assert conn.resp_body =~ "emakola_http_requests_total"
    assert conn.resp_body =~ "emakola_oban_jobs"
    assert get_resp_header(conn, "content-type") == ["text/plain; version=0.0.4; charset=utf-8"]
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "does not serve other paths" do
    conn = Endpoint.call(conn(:get, "/"), [])
    assert conn.status == 404
    assert conn.resp_body == "not found"
  end
end
