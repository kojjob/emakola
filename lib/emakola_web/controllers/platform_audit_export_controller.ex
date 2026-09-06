defmodule EmakolaWeb.PlatformAuditExportController do
  @moduledoc """
  Streams the platform audit log as CSV under the same filters the ledger
  page shows. A plain controller because a download needs a real HTTP
  response; it re-verifies the platform session and :view_audit_log itself,
  the way ImpersonateSessionController does, since no LiveView hook runs
  here. Capped at 10,000 rows per download.
  """
  use EmakolaWeb, :controller

  alias Emakola.Accounts.PlatformAuditFamilies, as: Families
  alias Emakola.Accounts.PlatformAuditSearch, as: Search
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Accounts.Sessions
  alias EmakolaWeb.AuthTokens

  @max_rows 10_000
  @header ~w(time action severity family actor ip metadata)

  def export(conn, params) do
    if staff_allowed?(conn) do
      stream_csv(conn, Search.from_params(params))
    else
      conn |> put_status(401) |> text("Unauthorized")
    end
  end

  defp stream_csv(conn, search) do
    conn =
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=\"audit-log-#{Date.utc_today()}.csv\""
      )
      |> send_chunked(200)

    {:ok, conn} = chunk(conn, NimbleCSV.RFC4180.dump_to_iodata([@header]))

    search
    |> Search.stream()
    |> Stream.take(@max_rows)
    |> Stream.chunk_every(200)
    |> Enum.reduce_while({conn, %{}}, fn entries, {conn, actors} ->
      actors = Search.actor_names(actors, entries)
      rows = Enum.map(entries, &row(&1, actors))

      case chunk(conn, NimbleCSV.RFC4180.dump_to_iodata(rows)) do
        {:ok, conn} -> {:cont, {conn, actors}}
        {:error, _reason} -> {:halt, {conn, actors}}
      end
    end)
    |> elem(0)
  end

  defp row(entry, actors) do
    [
      DateTime.to_iso8601(entry.inserted_at),
      Atom.to_string(entry.action),
      entry.action |> Families.severity_of() |> Atom.to_string(),
      entry.action |> Families.family_of() |> to_string(),
      actor_label(entry.actor_id, actors),
      entry.ip || "",
      Jason.encode!(entry.metadata)
    ]
  end

  defp actor_label(nil, _actors), do: "system"

  defp actor_label(actor_id, actors) do
    case actors[actor_id] do
      %{email: email} -> email
      nil -> actor_id
    end
  end

  defp staff_allowed?(conn) do
    with {:ok, session_id} <-
           AuthTokens.verify_platform_session(get_session(conn, :platform_session_token)),
         {:ok, user, _session} <- Sessions.verify_session_id(session_id) do
      PlatformPermissions.allowed?(user, :view_audit_log)
    else
      _ -> false
    end
  end
end
