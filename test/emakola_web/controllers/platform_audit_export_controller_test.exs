defmodule EmakolaWeb.PlatformAuditExportControllerTest do
  @moduledoc """
  CSV export of the platform audit log: staff with :view_audit_log get the
  filtered set as an attachment; everyone else gets 401.
  """
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  alias Emakola.Accounts.PlatformAudit

  @path "/platform/audit-log/export"

  test "without a platform session returns 401", %{conn: conn} do
    conn = get(conn, @path)

    assert response(conn, 401) == "Unauthorized"
  end

  test "staff without :view_audit_log returns 401", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

    conn = get(conn, @path)

    assert response(conn, 401) == "Unauthorized"
  end

  test "streams the filtered log as a CSV attachment", %{conn: conn} do
    {conn, owner, _session} = setup_platform_staff(conn)

    {:ok, _} =
      PlatformAudit.log(
        :store_suspended,
        owner,
        %{"store_slug" => "osu-sneaker-loft"},
        "10.0.0.1"
      )

    {:ok, _} = PlatformAudit.log(:sign_out, nil)

    conn = get(conn, @path <> "?family=stores")

    assert response_content_type(conn, :csv) =~ "text/csv"

    assert get_resp_header(conn, "content-disposition") |> hd() =~
             ~s(attachment; filename="audit-log-)

    body = response(conn, 200)
    [header | rows] = body |> String.trim() |> String.split(~r/\r?\n/)

    assert header == "time,action,severity,family,actor,ip,metadata"
    assert length(rows) == 1
    assert hd(rows) =~ "store_suspended,amber,stores," <> to_string(owner.email) <> ",10.0.0.1"
    assert hd(rows) =~ "osu-sneaker-loft"
  end
end
