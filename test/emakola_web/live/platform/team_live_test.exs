defmodule EmakolaWeb.Platform.TeamLiveTest do
  @moduledoc """
  Tests for the /platform/team management page: staff roster, permission
  editing, owner-only controls (enforced server-side, not just hidden),
  force logout, 2FA reset, deactivation, and the invite lifecycle.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Swoosh.TestAssertions

  require Ash.Query

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
      assert html =~ "Invites"
    end
  end

  describe "invite flow" do
    test "owner invites a new team member with permission checkboxes", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      email = Factory.unique_email()

      {:ok, view, _html} = live(conn, "/platform/team")
      flush_emails()

      view |> element("#open-invite-modal") |> render_click()

      view
      |> form("#invite-form", %{
        "email" => email,
        "permissions" => ["manage_stores", "manage_team"]
      })
      |> render_submit()

      assert [invite] = open_invites()
      assert to_string(invite.email) == email
      assert Enum.sort(invite.permissions) == [:manage_stores, :manage_team]
      assert has_element?(view, "#invite-#{invite.id}", email)

      assert_email_sent(fn sent -> assert {_, ^email} = hd(sent.to) end)
    end
  end

  describe "second-pass polish" do
    test "queue rows carry a 2FA pill and invites a countdown", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])
      invite = Factory.create_platform_invite!(permissions: [:manage_merchants])

      {:ok, view, _html} = live(conn, "/platform/team")

      # Staff created without TOTP wear an explicit 2FA-off pill in the queue
      assert has_element?(view, "#staff-#{staff.id} [data-twofa='off']")
      # Invites show a countdown, not just raw dates
      assert has_element?(view, "#invite-#{invite.id}", "Expires in")
    end

    test "permissions render as toggle cards with a granted state", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()

      assert has_element?(
               view,
               "#edit-permissions-form label[data-permission='manage_stores'][data-granted]"
             )

      refute has_element?(
               view,
               "#edit-permissions-form label[data-permission='manage_billing'][data-granted]"
             )
    end
  end

  describe "edit permissions" do
    test "owner edits a staff member's permissions via the modal", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()

      view
      |> form("#edit-permissions-form", %{
        "permissions" => ["manage_merchants", "view_audit_log"]
      })
      |> render_submit()

      updated = reload_user!(staff)
      assert Enum.sort(updated.platform_permissions) == [:manage_merchants, :view_audit_log]
      refute updated.is_owner
      assert has_element?(view, "#staff-#{staff.id}", "manage_merchants")
    end

    test "owner can promote a staff member to owner", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()

      view
      |> form("#edit-permissions-form", %{
        "permissions" => ["manage_stores"],
        "is_owner" => "true"
      })
      |> render_submit()

      assert reload_user!(staff).is_owner
    end

    test "non-owner does not see the is_owner toggle or deactivate buttons", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      refute has_element?(view, "#deactivate-staff-#{staff.id}")

      view |> element("#edit-staff-#{staff.id}") |> render_click()
      refute has_element?(view, "#edit-is-owner")
    end

    test "selecting a member shows the Studio panel with security actions", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()

      assert has_element?(view, "#team-panel", to_string(staff.email))
      assert has_element?(view, "#team-panel #force-logout-#{staff.id}")
      assert has_element?(view, "#team-panel #edit-permissions-form")
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

      view |> element("#edit-staff-#{staff.id}") |> render_click()
      view |> element("#force-logout-#{staff.id}") |> render_click()

      assert {:ok, []} = Sessions.list_active_for_user(staff.id)
    end

    test "reset 2FA clears the target's TOTP secret", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = setup_totp!(create_staff!([:manage_stores]))

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()
      view |> element("#reset-totp-#{staff.id}") |> render_click()

      assert is_nil(reload_user!(staff).totp_secret)
    end
  end

  describe "deactivate / reactivate" do
    test "owner deactivates then reactivates a staff member", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()
      view |> element("#deactivate-staff-#{staff.id}") |> render_click()
      assert has_element?(view, "#staff-#{staff.id}", "Deactivated")
      assert %DateTime{} = reload_user!(staff).deactivated_at

      view |> element("#reactivate-staff-#{staff.id}") |> render_click()
      assert is_nil(reload_user!(staff).deactivated_at)
    end
  end

  describe "remove from team" do
    test "owner removes a member: off the roster, no permissions, no sessions, audited",
         %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])
      Factory.create_user_session!(staff)

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()
      view |> element("#remove-staff-#{staff.id}") |> render_click()

      refute has_element?(view, "#staff-#{staff.id}")
      removed = reload_user!(staff)
      assert removed.platform_permissions == []
      refute removed.is_owner
      assert {:ok, []} = Sessions.list_active_for_user(staff.id)

      removed_ids =
        Emakola.Accounts.PlatformAuditLog
        |> Ash.Query.for_read(:list)
        |> Ash.Query.filter(action == :staff_removed)
        |> Ash.read!(authorize?: false)
        |> Map.fetch!(:results)
        |> Enum.map(& &1.metadata["user_id"])

      assert staff.id in removed_ids
    end

    test "a non-owner sees no remove button and a crafted event is rejected", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])
      staff = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#edit-staff-#{staff.id}") |> render_click()
      refute has_element?(view, "#remove-staff-#{staff.id}")

      html = render_click(view, "remove", %{"id" => staff.id})

      assert html =~ "Only platform owners"
      assert reload_user!(staff).platform_permissions == [:manage_stores]
    end

    test "an owner cannot remove themselves", %{conn: conn} do
      {conn, owner, _session} = setup_platform_staff(conn)

      {:ok, view, _html} = live(conn, "/platform/team")

      html = render_click(view, "remove", %{"id" => owner.id})

      assert html =~ "cannot remove yourself"
      assert reload_user!(owner).is_owner
    end
  end

  describe "invite actions" do
    test "owner revokes a pending invite", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      invite = Factory.create_platform_invite!()

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#revoke-invite-#{invite.id}") |> render_click()

      refute has_element?(view, "#invite-#{invite.id}")
      assert %DateTime{} = Ash.get!(PlatformInvite, invite.id).revoked_at
    end

    test "owner resends a pending invite", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      invite = Factory.create_platform_invite!(permissions: [:manage_stores])
      email = to_string(invite.email)

      {:ok, view, _html} = live(conn, "/platform/team")
      flush_emails()

      view |> element("#resend-invite-#{invite.id}") |> render_click()

      assert %DateTime{} = Ash.get!(PlatformInvite, invite.id).revoked_at

      assert [new_invite] = open_invites()
      assert to_string(new_invite.email) == email
      assert new_invite.permissions == [:manage_stores]
      assert has_element?(view, "#invite-#{new_invite.id}", email)

      assert_email_sent(fn sent -> assert {_, ^email} = hd(sent.to) end)
    end
  end

  describe "roster filters" do
    test "status chips narrow the roster and the header counts what is shown", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      secured = setup_totp!(create_staff!([:manage_stores]))
      exposed = create_staff!([:manage_billing])

      {:ok, view, _html} = live(conn, "/platform/team")

      assert has_element?(view, "#filter-twofa_off", "2FA off")

      view |> element("#filter-twofa_off") |> render_click()

      assert has_element?(view, "#staff-#{exposed.id}")
      refute has_element?(view, "#staff-#{secured.id}")
      assert has_element?(view, "#roster-count", "of 3")
      assert has_element?(view, "#roster-hidden", "hidden")

      view |> element("#clear-filters") |> render_click()

      assert has_element?(view, "#staff-#{secured.id}")
      refute has_element?(view, "#roster-hidden")
    end

    test "search and the permission select narrow by email and permission", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      billing = create_staff!([:manage_billing])
      stores = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      view
      |> form("#roster-filter-form", %{"search" => to_string(billing.email), "permission" => ""})
      |> render_change()

      assert has_element?(view, "#staff-#{billing.id}")
      refute has_element?(view, "#staff-#{stores.id}")

      view
      |> form("#roster-filter-form", %{"search" => "", "permission" => "manage_stores"})
      |> render_change()

      assert has_element?(view, "#staff-#{stores.id}")
      refute has_element?(view, "#staff-#{billing.id}")
    end

    test "the invites chip shows only open invites", %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      staff = create_staff!([:manage_stores])
      invite = Factory.create_platform_invite!()

      {:ok, view, _html} = live(conn, "/platform/team")

      view |> element("#filter-invites") |> render_click()

      refute has_element?(view, "#staff-#{staff.id}")
      assert has_element?(view, "#invite-#{invite.id}")
    end
  end

  describe "presence" do
    test "rows say who is online, who was seen recently, and who never signed in",
         %{conn: conn} do
      {conn, _owner, _session} = setup_platform_staff(conn)
      online = create_staff!([:manage_stores])
      Factory.create_user_session!(online)
      away = create_staff!([:manage_stores])

      Factory.create_user_session!(away,
        last_seen_at: DateTime.add(DateTime.utc_now(), -3, :hour)
      )

      never = create_staff!([:manage_stores])

      {:ok, view, _html} = live(conn, "/platform/team")

      assert has_element?(view, "#staff-#{online.id} [data-presence='online']")
      assert has_element?(view, "#staff-#{away.id} [data-presence='away']")
      assert has_element?(view, "#staff-#{never.id} [data-presence='offline']")

      view |> element("#edit-staff-#{away.id}") |> render_click()
      assert has_element?(view, "#team-panel", "Last seen")

      view |> element("#edit-staff-#{online.id}") |> render_click()
      assert has_element?(view, "#team-panel", "Online")
    end
  end
end
