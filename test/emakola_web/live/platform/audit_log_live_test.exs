defmodule EmakolaWeb.Platform.AuditLogLiveTest do
  @moduledoc """
  Tests for the /platform/audit-log page: permission gating (mount and
  load_more), streamed keyset pagination, batched actor email resolution,
  and metadata chip rendering.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Factory

  defp seed_logs!(count) do
    for n <- 1..count do
      seq = n |> Integer.to_string() |> String.pad_leading(2, "0")
      {:ok, _} = PlatformAudit.log(:sign_out, nil, %{"seq" => "row-#{seq}"})
    end
  end

  defp set_permissions!(user, permissions) do
    user
    |> Ash.Changeset.for_update(:set_platform_permissions, %{platform_permissions: permissions})
    |> Ash.update!(authorize?: false)
  end

  describe "access" do
    test "staff without :view_audit_log is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, "/platform/audit-log")

      assert flash["error"] =~ "permission"
    end

    test "non-owner staff with :view_audit_log sees the page", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:view_audit_log])

      {:ok, _view, html} = live(conn, "/platform/audit-log")

      assert html =~ "Audit log"
    end

    test "owner sees the page", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform/audit-log")

      assert html =~ "Audit log"
    end
  end

  describe "pagination" do
    test "shows 50 newest entries, load more appends the rest, then the button disappears",
         %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      seed_logs!(55)

      {:ok, view, html} = live(conn, "/platform/audit-log")

      # Newest first: row-55 down to row-06 on the first page.
      assert html =~ "row-55"
      assert html =~ "row-06"
      refute html =~ "row-05"

      {newest_pos, _} = :binary.match(html, "row-55")
      {oldest_pos, _} = :binary.match(html, "row-06")
      assert newest_pos < oldest_pos

      html = view |> element("#load-more") |> render_click()

      assert html =~ "row-05"
      assert html =~ "row-01"
      refute has_element?(view, "#load-more")
    end
  end

  describe "actor resolution" do
    test "shows actor email, 'system' for nil actors, shortened uuid for unknown ids",
         %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = Factory.create_user!()
      ghost_id = Ash.UUID.generate()

      {:ok, _} = PlatformAudit.log(:sign_in_succeeded, staff)
      {:ok, _} = PlatformAudit.log(:sign_in_failed, nil)
      {:ok, _} = PlatformAudit.log(:sign_out, ghost_id)

      {:ok, _view, html} = live(conn, "/platform/audit-log")

      assert html =~ to_string(staff.email)
      assert html =~ "system"
      assert html =~ String.slice(ghost_id, 0, 8)
    end
  end

  describe "metadata" do
    test "renders metadata as escaped key/value chips", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)

      {:ok, _} = PlatformAudit.log(:invite_created, nil, %{"email" => "x@y.z"})
      {:ok, _} = PlatformAudit.log(:sign_out, nil, %{"note" => "<b>bold</b>"})
      {:ok, _} = PlatformAudit.log(:permissions_changed, nil, %{"added" => ["a", "b"]})

      {:ok, _view, html} = live(conn, "/platform/audit-log")

      assert html =~ "email"
      assert html =~ "x@y.z"
      assert html =~ "&lt;b&gt;bold&lt;/b&gt;"
      refute html =~ "<b>bold</b>"
      assert html =~ "a, b"
    end
  end

  describe "disconnected mount" do
    test "renders a loading shell without hitting the database", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      seed_logs!(1)

      conn = get(conn, "/platform/audit-log")

      html = html_response(conn, 200)
      assert html =~ "Loading audit log"
      refute html =~ "row-01"
    end
  end

  describe "load_more authorization" do
    test "permission revoked after mount: load_more appends nothing", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:view_audit_log])
      seed_logs!(51)

      {:ok, view, _html} = live(conn, "/platform/audit-log")

      set_permissions!(user, [:manage_stores])

      html = view |> element("#load-more") |> render_click()

      refute html =~ "row-01"
      assert html =~ "Could not verify your access"
    end
  end
end
