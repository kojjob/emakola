defmodule EmakolaWeb.HealthController do
  use EmakolaWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
