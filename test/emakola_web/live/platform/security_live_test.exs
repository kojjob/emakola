defmodule EmakolaWeb.Platform.SecurityLiveTest do
  @moduledoc """
  Tests for the self-service /platform/security page: own 2FA status with
  code-gated rotation (the current code is consumed on verify, blocking
  replay), and own active sessions with ownership-checked revocation.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Ecto.Query

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.Sessions
  alias Emakola.Accounts.TOTP
  alias Emakola.Accounts.UserSession
  alias Emakola.Factory

  describe "access" do
    test "any staff with limited permissions can access", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      {:ok, _view, html} = live(conn, "/platform/security")

      assert html =~ "Security"
      assert html =~ "Active sessions"
    end

    test "a merchant (non-staff) is bounced", %{conn: conn} do
      {conn, _merchant, _store} = setup_authenticated_merchant(conn)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/platform/security")
    end
  end

  describe "disconnected mount" do
    test "renders a loading shell for the sessions list", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      conn = get(conn, "/platform/security")

      assert html_response(conn, 200) =~ "Loading sessions"
    end
  end

  describe "two-factor status" do
    test "shows enabled state for a user with TOTP", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      enable_totp!(user)

      {:ok, _view, html} = live(conn, "/platform/security")

      assert html =~ "Two-factor authentication is enabled"
      assert html =~ "rotate-totp"
    end
  end

  describe "2FA rotation" do
    test "wrong current code shows an error and leaves the secret unchanged",
         %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      {_user, secret} = enable_totp!(user)

      {:ok, view, _html} = live(conn, "/platform/security")
      view |> element("#rotate-totp") |> render_click()

      html = submit_verify(view, "000000")

      assert html =~ "Invalid code"
      refute html =~ "totp-rotate-confirm-form"
      assert reload_user!(user).totp_secret == secret
    end

    test "correct current code shows the new QR code and manual secret", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      {_user, secret} = enable_totp!(user)

      {:ok, view, _html} = live(conn, "/platform/security")
      view |> element("#rotate-totp") |> render_click()

      html = submit_verify(view, NimbleTOTP.verification_code(secret))

      assert html =~ "totp-rotate-confirm-form"
      assert html =~ "<svg"
      assert [base32] = extract_manual_secret(html)
      new_secret = Base.decode32!(base32, padding: false)
      assert new_secret != secret
      # Nothing persisted yet — confirmation pending
      assert reload_user!(user).totp_secret == secret
    end

    test "confirming with a code from the new secret replaces the secret and audits",
         %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      {_user, secret} = enable_totp!(user)

      {:ok, view, _html} = live(conn, "/platform/security")
      view |> element("#rotate-totp") |> render_click()

      html = submit_verify(view, NimbleTOTP.verification_code(secret))
      [base32] = extract_manual_secret(html)
      new_secret = Base.decode32!(base32, padding: false)

      html = submit_confirm(view, NimbleTOTP.verification_code(new_secret))

      assert html =~ "Two-factor authentication is enabled"
      refute html =~ "totp-rotate-confirm-form"

      reloaded = reload_user!(user)
      assert reloaded.totp_secret == new_secret
      assert reloaded.totp_secret != secret

      assert [entry | _] = audit_entries(:totp_enabled)
      assert entry.actor_id == user.id
    end

    test "an invalid confirmation code keeps the old secret", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      {_user, secret} = enable_totp!(user)

      {:ok, view, _html} = live(conn, "/platform/security")
      view |> element("#rotate-totp") |> render_click()
      submit_verify(view, NimbleTOTP.verification_code(secret))

      html = submit_confirm(view, "000000")

      assert html =~ "Invalid code"
      assert html =~ "totp-rotate-confirm-form"
      assert reload_user!(user).totp_secret == secret
    end

    test "a verified current code cannot start a second rotation (replay)",
         %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      {_user, secret} = enable_totp!(user)
      code = NimbleTOTP.verification_code(secret)

      {:ok, view, _html} = live(conn, "/platform/security")
      view |> element("#rotate-totp") |> render_click()

      assert submit_verify(view, code) =~ "totp-rotate-confirm-form"

      # Abandon and retry with the SAME code — it was consumed on verify
      view |> element("#cancel-rotation") |> render_click()
      view |> element("#rotate-totp") |> render_click()

      html = submit_verify(view, code)

      assert html =~ "Invalid code"
      refute html =~ "totp-rotate-confirm-form"
    end
  end

  describe "active sessions" do
    test "lists only the current user's active sessions with device labels",
         %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)

      Factory.create_user_session!(user, %{
        ip: "10.0.0.5",
        user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
      })

      intruder = Factory.create_platform_owner!()
      Factory.create_user_session!(intruder, %{ip: "203.0.113.9"})

      {:ok, _view, html} = live(conn, "/platform/security")

      assert html =~ "10.0.0.5"
      assert html =~ "Mac"
      refute html =~ "203.0.113.9"
    end

    test "the current session is badged", %{conn: conn} do
      {conn, user, session} = setup_platform_staff(conn)
      other = Factory.create_user_session!(user, %{ip: "10.0.0.5"})

      {:ok, view, _html} = live(conn, "/platform/security")

      assert view |> element("#session-#{session.id}") |> render() =~ "Current session"
      refute view |> element("#session-#{other.id}") |> render() =~ "Current session"
    end

    test "revoking another of one's own sessions revokes and broadcasts disconnect",
         %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      other = Factory.create_user_session!(user, %{ip: "10.0.0.5"})

      Phoenix.PubSub.subscribe(Emakola.PubSub, Sessions.live_socket_id(other.id))

      {:ok, view, _html} = live(conn, "/platform/security")

      html = view |> element("#revoke-session-#{other.id}") |> render_click()

      refute html =~ "session-#{other.id}"
      assert %DateTime{} = reload_session!(other).revoked_at
      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
    end

    test "a crafted revoke event with another user's session id is a no-op",
         %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      intruder = Factory.create_platform_owner!()
      intruder_session = Factory.create_user_session!(intruder)

      {:ok, view, _html} = live(conn, "/platform/security")

      render_click(view, "revoke_session", %{"id" => intruder_session.id})

      assert is_nil(reload_session!(intruder_session).revoked_at)
    end

    test "a crafted revoke event with a garbage id is a no-op", %{conn: conn} do
      {conn, user, session} = setup_platform_staff(conn)

      {:ok, view, _html} = live(conn, "/platform/security")

      render_click(view, "revoke_session", %{"id" => "not-a-uuid"})

      assert {:ok, [_]} = Sessions.list_active_for_user(user.id)
      assert is_nil(reload_session!(session).revoked_at)
    end

    test "revoking the current session is allowed and revokes it", %{conn: conn} do
      {conn, _user, session} = setup_platform_staff(conn)

      {:ok, view, _html} = live(conn, "/platform/security")

      # In production the disconnect broadcast kills this very LiveView and
      # the user lands back on /platform/login. The test socket is not
      # subscribed to the live_socket_id topic, so we just assert the DB.
      render_click(view, "revoke_session", %{"id" => session.id})

      assert %DateTime{} = reload_session!(session).revoked_at
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp submit_verify(view, code) do
    view |> form("#totp-rotate-verify-form", totp: %{code: code}) |> render_submit()
  end

  defp submit_confirm(view, code) do
    view |> form("#totp-rotate-confirm-form", totp: %{code: code}) |> render_submit()
  end

  defp extract_manual_secret(html) do
    Regex.run(~r/id="totp-manual-secret"[^>]*>\s*([A-Z2-7]+)\s*</, html, capture: :all_but_first)
  end

  # Enrol TOTP, then backdate totp_last_used_at: setup_totp marks the
  # enrolment code as used, which would block a freshly minted code in
  # the same 30s window via the `since:` reuse guard.
  defp enable_totp!(user) do
    secret = TOTP.generate_secret()

    user
    |> Ash.Changeset.for_update(:setup_totp, %{
      secret: secret,
      code: NimbleTOTP.verification_code(secret)
    })
    |> Ash.update!(authorize?: false)

    set_totp_last_used_at!(user, DateTime.add(DateTime.utc_now(), -120, :second))

    {reload_user!(user), secret}
  end

  defp set_totp_last_used_at!(user, datetime) do
    {1, _} =
      Emakola.Repo.update_all(
        from(u in "users", where: u.id == type(^user.id, :binary_id)),
        set: [totp_last_used_at: datetime]
      )

    :ok
  end

  defp reload_user!(user) do
    {:ok, user} = Emakola.Accounts.get_user_by_id(user.id, authorize?: false)
    user
  end

  defp reload_session!(session), do: Ash.get!(UserSession, session.id, authorize?: false)

  defp audit_entries(action) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.read!(authorize?: false)
    |> Map.fetch!(:results)
    |> Enum.filter(&(&1.action == action))
  end
end
