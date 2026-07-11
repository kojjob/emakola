defmodule EmakolaWeb.Platform.TeamLiveTest do
  @moduledoc """
  Tests for the /platform/team management page: staff roster, permission
  editing, owner-only controls (enforced server-side, not just hidden),
  force logout, 2FA reset, deactivation, and the invite lifecycle.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Swoosh.TestAssertions

  alias Emakola.Accounts.PlatformInvite
  alias Emakola.Accounts.Sessions
  alias Emakola.Accounts.TOTP
  alias Emakola.Accounts.User
  alias Emakola.Factory

  defp create_staff!(permissions) do
    Factory.create_user!()
    |> Ash.Changeset.for_update(:set_platform_permissions, %{platform_permissions: permissions})
    |> Ash.update!(authorize?: false)
  end

  defp reload_user!(user), do: Ash.get!(User, user.id, authorize?: false)

  defp open_invites do
    PlatformInvite
    |> Ash.Query.for_read(:list_open)
    |> Ash.read!(authorize?: false)
  end

  # The user factory sends welcome emails — drain them so assertions
  # below only see the invite email.
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  defp setup_totp!(user) do
    secret = TOTP.generate_secret()

    user
    |> Ash.Changeset.for_update(:setup_totp, %{
      secret: secret,
      code: NimbleTOTP.verification_code(secret)
    })
    |> Ash.update!(authorize?: false)
  end

  describe "access" do
    test "staff without :manage_team is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      assert {:error, {:redirect, %{to: "/platform"}}} = live(conn, "/platform/team")
    end
  end

  describe "roster" do
    test "owner sees staff and pending invites", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])
      invite = Factory.create_platform_invite!(permissions: [:manage_merchants])

      {:ok, _view, html} = live(conn, "/platform/team")

      assert html =~ to_string(staff.email)
      assert html =~ "Owner"
      assert html =~ "manage_stores"
      assert html =~ to_string(invite.email)
      assert html =~ "Pending invites"
    end
  end

  describe "invite flow" do
    test "owner invites a new team member with permission checkboxes", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      email = Factory.unique_email()

      {:ok, view, _html} = live(conn, "/platform/team")
      flush_emails()

      view |> element("#open-invite-modal") |> render_click()

      html =
        view
        |> element("#invite-form")
        |> render_submit(%{"email" => email, "permissions" => ["manage_stores", "manage_team"]})

      assert html =~ email

      assert [invite] = open_invites()
      assert to_string(invite.email) == email
      assert Enum.sort(invite.permissions) == [:manage_stores, :manage_team]

      assert_email_sent(fn sent -> assert {_, ^email} = hd(sent.to) end)
    end
  end

  describe "edit permissions" do
    test "owner edits a staff member's permissions via the modal", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()

      html =
        view
        |> element("#edit-permissions-form")
        |> render_submit(%{"permissions" => ["manage_merchants", "view_audit_log"]})

      assert html =~ "manage_merchants"

      updated = reload_user!(staff)
      assert Enum.sort(updated.platform_permissions) == [:manage_merchants, :view_audit_log]
      refute updated.is_owner
    end

    test "owner can promote a staff member to owner", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()

      view
      |> element("#edit-permissions-form")
      |> render_submit(%{"permissions" => ["manage_stores"], "is_owner" => "true"})

      assert reload_user!(staff).is_owner
    end

    test "non-owner does not see the is_owner toggle or deactivate buttons", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])
      staff = create_staff!([:manage_stores])

      {:ok, view, html} = live(conn, "/platform/team")

      refute html =~ "deactivate-staff-#{staff.id}"

      modal_html = view |> element("#edit-staff-#{staff.id}") |> render_click()
      refute modal_html =~ ~s(name="is_owner")
    end
  end

  describe "injection: crafted events from a non-owner with manage_team" do
    test "a crafted deactivate event is rejected", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      html = render_click(view, "deactivate", %{"id" => staff.id})

      assert html =~ "Only platform owners"
      assert is_nil(reload_user!(staff).deactivated_at)
    end

    test "a crafted is_owner save is rejected", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()

      html =
        render_submit(view, "save_permissions", %{
          "permissions" => ["manage_stores"],
          "is_owner" => "true"
        })

      assert html =~ "Only platform owners"
      refute reload_user!(staff).is_owner
    end
  end

  describe "event re-authorization after permission revocation" do
    defp set_permissions!(user, attrs) do
      user
      |> Ash.Changeset.for_update(:set_platform_permissions, attrs)
      |> Ash.update!(authorize?: false)
    end

    test "a crafted send_invite is rejected when :manage_team is revoked after mount",
         %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_team])
      email = Factory.unique_email()

      {:ok, view, _html} = live(conn, "/platform/team")

      # Revoke the permission in the DB after the socket is already mounted.
      set_permissions!(user, %{platform_permissions: [:manage_stores]})

      html =
        render_submit(view, "send_invite", %{
          "email" => email,
          "permissions" => ["manage_stores"]
        })

      assert html =~ "don&#39;t have permission to manage the team"
      assert open_invites() == []
    end

    test "a crafted deactivate is rejected when ownership is revoked after mount",
         %{conn: conn} do
      {conn, owner, _session} = setup_platform_staff(conn)
      _remaining_owner = Factory.create_platform_owner!()
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      # Demote the mounted owner in the DB after mount (another owner remains).
      set_permissions!(owner, %{is_owner: false, platform_permissions: []})

      html = render_click(view, "deactivate", %{"id" => staff.id})

      assert html =~ "don&#39;t have permission to manage the team"
      assert is_nil(reload_user!(staff).deactivated_at)
    end
  end

  describe "session and 2FA controls" do
    test "force logout revokes the target's sessions", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])
      Factory.create_user_session!(staff)

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#force-logout-#{staff.id}") |> render_click()

      assert {:ok, []} = Sessions.list_active_for_user(staff.id)
    end

    test "reset 2FA clears the target's TOTP secret", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = setup_totp!(create_staff!([:manage_stores]))

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#reset-totp-#{staff.id}") |> render_click()

      assert is_nil(reload_user!(staff).totp_secret)
    end
  end

  describe "deactivate / reactivate" do
    test "owner deactivates then reactivates a staff member", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      html = view |> element("#deactivate-staff-#{staff.id}") |> render_click()
      assert html =~ "Deactivated"
      assert %DateTime{} = reload_user!(staff).deactivated_at

      view |> element("#reactivate-staff-#{staff.id}") |> render_click()
      assert is_nil(reload_user!(staff).deactivated_at)
    end
  end

  describe "invite actions" do
    test "owner revokes a pending invite", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      invite = Factory.create_platform_invite!()

      {:ok, view, _html} = live(conn, "/platform/team")

      html = view |> element("#revoke-invite-#{invite.id}") |> render_click()

      refute html =~ to_string(invite.email)
      assert %DateTime{} = Ash.get!(PlatformInvite, invite.id).revoked_at
    end

    test "owner resends a pending invite", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      invite = Factory.create_platform_invite!(permissions: [:manage_stores])
      email = to_string(invite.email)

      {:ok, view, _html} = live(conn, "/platform/team")
      flush_emails()

      html = view |> element("#resend-invite-#{invite.id}") |> render_click()

      assert html =~ email
      assert %DateTime{} = Ash.get!(PlatformInvite, invite.id).revoked_at

      assert [new_invite] = open_invites()
      assert to_string(new_invite.email) == email
      assert new_invite.permissions == [:manage_stores]

      assert_email_sent(fn sent -> assert {_, ^email} = hd(sent.to) end)
    end
  end
end
