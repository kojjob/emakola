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

  defp backdate!(entry, days) do
    import Ecto.Query
    at = DateTime.utc_now() |> DateTime.add(-days, :day) |> DateTime.truncate(:second)

    {1, _} =
      Emakola.Repo.update_all(
        from(l in Emakola.Accounts.PlatformAuditLog, where: l.id == ^entry.id),
        set: [inserted_at: at]
      )
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

  describe "timeline treatment" do
    test "entries carry a severity rail matching their action family", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)

      {:ok, _} = PlatformAudit.log(:sign_in_failed, nil)
      {:ok, _} = PlatformAudit.log(:invite_accepted, nil)
      {:ok, _} = PlatformAudit.log(:sign_out, nil)

      {:ok, view, _html} = live(conn, "/platform/audit-log")

      assert has_element?(view, "#audit-entries[phx-update='stream']")
      assert has_element?(view, "#audit-entries [data-severity='red']")
      assert has_element?(view, "#audit-entries [data-severity='green']")
      assert has_element?(view, "#audit-entries [data-severity='neutral']")
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

  describe "ledger filters" do
    setup %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      {:ok, _} = PlatformAudit.log(:store_suspended, nil, %{"store_slug" => "osu-sneaker-loft"})
      {:ok, _} = PlatformAudit.log(:sign_out, nil, %{}, "10.9.8.7")
      {:ok, _} = PlatformAudit.log(:payout_approved, nil, %{"amount" => "1250"})
      %{conn: conn}
    end

    test "family in the URL narrows the ledger and marks the chip", %{conn: conn} do
      {:ok, view, html} = live(conn, "/platform/audit-log?family=stores")

      assert html =~ "Store suspended"
      refute view |> element("#audit-entries") |> render() =~ "Sign out"
      assert has_element?(view, "#audit-families button.bg-white", "Stores")
    end

    test "clicking a family chip patches the URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/platform/audit-log")

      html = view |> element("#audit-families button[phx-value-family=finance]") |> render_click()

      assert_patch(view, "/platform/audit-log?family=finance")
      assert html =~ "Payout approved"
      refute html =~ "Store suspended"
    end

    test "severity and range selects patch the URL together", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/platform/audit-log")

      html =
        view
        |> form("#audit-filters", %{"severity" => "amber", "range" => "week"})
        |> render_change()

      assert_patch(view, "/platform/audit-log?range=week&severity=amber")
      assert html =~ "Store suspended"
      refute view |> element("#audit-entries") |> render() =~ "Sign out"
    end

    test "search matches ip and metadata and patches the URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/platform/audit-log")

      html = view |> form("#audit-search", %{"q" => "10.9"}) |> render_change()

      assert_patch(view, "/platform/audit-log?q=10.9")
      assert html =~ "Sign out"
      refute html =~ "Store suspended"
    end

    test "chips carry counts and the footer says how many are shown", %{conn: conn} do
      {:ok, view, html} = live(conn, "/platform/audit-log")

      assert has_element?(view, "#audit-families button", "Stores")
      assert has_element?(view, "#audit-families button .tab-count", "1")
      # Creating the owner audits too, so the exact total is not fixed;
      # everything fits on one page, so shown equals total.
      assert view |> element("#audit-total") |> render() =~ ~r/Showing (\d+) of \1\b/
      refute html =~ "Showing 0 of"
    end

    test "an empty result shows an empty state instead of a bare table", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/platform/audit-log?family=moderation")

      assert html =~ "No events match"
    end

    test "the export link carries the current filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/platform/audit-log?family=stores")

      assert has_element?(view, "#audit-export[href='/platform/audit-log/export?family=stores']")
    end
  end

  describe "day bands" do
    test "one band per day, today named", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      {:ok, _} = PlatformAudit.log(:sign_out, nil)
      {:ok, _} = PlatformAudit.log(:sign_in_succeeded, nil)
      {:ok, old} = PlatformAudit.log(:totp_enabled, nil)
      backdate!(old, 3)

      {:ok, view, html} = live(conn, "/platform/audit-log")

      today = Date.to_iso8601(Date.utc_today())
      assert has_element?(view, "#audit-entries #entries-band-#{today}", "Today")
      assert length(Regex.scan(~r/id="entries-band-/, html)) == 2
    end
  end

  describe "targets and details" do
    test "metadata becomes a named target, a first detail, and a folded remainder",
         %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)

      {:ok, entry} =
        PlatformAudit.log(:store_suspended, nil, %{
          "store_name" => "Osu Sneaker Loft",
          "store_slug" => "osu-sneaker-loft",
          "reason" => "Counterfeit listings",
          "store_id" => Ash.UUID.generate()
        })

      {:ok, view, html} = live(conn, "/platform/audit-log")

      assert html =~ "Osu Sneaker Loft"
      assert html =~ "Counterfeit listings"
      assert has_element?(view, "#entries-#{entry.id} .detail-more", "+1")
      assert has_element?(view, "#entries-#{entry.id}-meta.hidden")
    end
  end

  describe "live updates" do
    test "a matching new entry is counted and shown on demand", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      {:ok, view, html} = live(conn, "/platform/audit-log?family=stores")
      refute html =~ "Store blocked"

      {:ok, _} = PlatformAudit.log(:store_blocked, nil)
      {:ok, _} = PlatformAudit.log(:sign_out, nil)

      html = render(view)
      assert html =~ "1 new"
      refute html =~ "Store blocked"

      html = view |> element("#show-new") |> render_click()
      assert html =~ "Store blocked"
      refute html =~ "1 new"
    end
  end
end
