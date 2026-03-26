defmodule EmakolaWeb.HealthController do
  use EmakolaWeb, :controller

  def show(conn, _params) do
    case Emakola.Repo.query("SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "ok"})

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", message: "database unreachable"})
    end
  end
end
