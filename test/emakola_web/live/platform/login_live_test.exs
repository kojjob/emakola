defmodule EmakolaWeb.Platform.LoginLiveTest do
  @moduledoc """
  Two-step platform login: password, then TOTP verify — or forced TOTP
  enrolment (QR + manual secret) on first sign-in.

  Note on rate limiting: `config :emakola, :disable_rate_limit` only disables
  the `EmakolaWeb.Plugs.RateLimiter` plug. `Emakola.RateLimit.check_rate/3`
  (called directly by the LiveView) stays active in tests, so each test gets
  a unique remote_ip to avoid Hammer counter collisions — and the limits
  themselves are covered below.
  """
  use EmakolaWeb.ConnCase, async: false

  use Emakola.LiveViewHelpers

  import Ecto.Query
  import Emakola.Factory

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.TOTP
  alias EmakolaWeb.AuthTokens

  @password "Password123!"
  @generic_error "Invalid email or password"

  setup %{conn: conn} do
    # Unique peer ip per test — Emakola.RateLimit keys on the client ip.
    # The LiveView reads it from get_connect_info(:peer_data), which comes
    # from the Plug.Test adapter's peer data, NOT conn.remote_ip.
    unique_ip = {10, 96, :rand.uniform(255), :rand.uniform(255)}

    conn =
      conn
      |> Map.replace!(:remote_ip, unique_ip)
      |> Plug.Test.put_peer_data(%{address: unique_ip, port: 54321, ssl_cert: nil})

    {:ok, conn: conn}
  end

  describe "credentials step" do
    test "mount renders the credentials step", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/platform/login")

      assert html =~ "Platform sign in"
      assert html =~ "platform-credentials-form"
      refute html =~ "platform-totp-form"
      refute html =~ "Create Account"
    end

    test "already-authenticated staff is redirected to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      assert {:error, {:redirect, %{to: "/platform"}}} = live(conn, "/platform/login")
    end

    test "wrong password shows a generic error and audits :sign_in_failed", %{conn: conn} do
      user = create_platform_owner!()

      {:ok, view, _html} = live(conn, "/platform/login")
      html = submit_credentials(view, user.email, "WrongPassword99!")

      assert html =~ @generic_error
      assert html =~ "platform-credentials-form"

      assert [entry | _] = audit_entries(:sign_in_failed)
      assert entry.actor_id == nil
      assert entry.metadata["email"] == to_string(user.email)
    end

    test "correct password for a plain (non-staff) user shows the same generic error",
         %{conn: conn} do
      user = create_user!()

      {:ok, view, _html} = live(conn, "/platform/login")
      html = submit_credentials(view, user.email, @password)

      assert html =~ @generic_error
      assert html =~ "platform-credentials-form"
      refute html =~ "platform-totp-setup-form"

      assert [entry | _] = audit_entries(:sign_in_failed)
      assert entry.metadata["email"] == to_string(user.email)
      assert entry.metadata["reason"] == "not_staff"
    end

    test "deactivated staff gets the same generic error", %{conn: conn} do
      user =
        create_user!()
        |> Ash.Changeset.for_update(:set_platform_permissions, %{
          platform_permissions: [:manage_stores]
        })
        |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:deactivate_staff, %{})
        |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(conn, "/platform/login")
      html = submit_credentials(view, user.email, @password)

      assert html =~ @generic_error
      assert html =~ "platform-credentials-form"
      assert [_entry | _] = audit_entries(:sign_in_failed)
    end

    test "more than 5 attempts within a minute are rate limited", %{conn: conn} do
      user = create_platform_owner!()
      {:ok, view, _html} = live(conn, "/platform/login")

      for _ <- 1..5 do
        assert submit_credentials(view, user.email, "WrongPassword99!") =~ @generic_error
      end

      html = submit_credentials(view, user.email, "WrongPassword99!")
      refute html =~ @generic_error
      assert html =~ "Too many attempts"
    end
  end

  describe "TOTP enrolment step (staff without TOTP)" do
    test "valid password shows QR code and manual secret", %{conn: conn} do
      user = create_platform_owner!()

      {:ok, view, _html} = live(conn, "/platform/login")
      html = submit_credentials(view, user.email, @password)

      assert html =~ "platform-totp-setup-form"
      assert html =~ "<svg"
      assert [base32] = extract_manual_secret(html)
      assert {:ok, _secret} = Base.decode32(base32, padding: false)
    end

    test "valid enrolment code persists TOTP and redirects to the exchange", %{conn: conn} do
      user = create_platform_owner!()

      {:ok, view, _html} = live(conn, "/platform/login")
      html = submit_credentials(view, user.email, @password)

      [base32] = extract_manual_secret(html)
      secret = Base.decode32!(base32, padding: false)

      submit_totp_setup(view, NimbleTOTP.verification_code(secret))

      {path, _flash} = assert_redirect(view)
      assert exchange_token_for(path) == user.id

      {:ok, reloaded} = Emakola.Accounts.get_user_by_id(user.id, authorize?: false)
      assert reloaded.totp_secret == secret
    end

    test "invalid enrolment code shows an error and stays on the setup step", %{conn: conn} do
      user = create_platform_owner!()

      {:ok, view, _html} = live(conn, "/platform/login")
      submit_credentials(view, user.email, @password)

      html = submit_totp_setup(view, "000000")

      assert html =~ "Invalid code"
      assert html =~ "platform-totp-setup-form"

      {:ok, reloaded} = Emakola.Accounts.get_user_by_id(user.id, authorize?: false)
      assert is_nil(reloaded.totp_secret)
    end
  end

  describe "TOTP verify step (staff with TOTP)" do
    test "valid code records use and redirects to the exchange", %{conn: conn} do
      {user, secret} = create_owner_with_totp!()

      {:ok, view, _html} = live(conn, "/platform/login")
      html = submit_credentials(view, user.email, @password)

      assert html =~ "platform-totp-form"
      refute html =~ "platform-totp-setup-form"

      before = user.totp_last_used_at
      submit_totp(view, NimbleTOTP.verification_code(secret))

      {path, _flash} = assert_redirect(view)
      assert exchange_token_for(path) == user.id

      {:ok, reloaded} = Emakola.Accounts.get_user_by_id(user.id, authorize?: false)
      assert DateTime.compare(reloaded.totp_last_used_at, before) == :gt
    end

    test "invalid code shows an error and audits :totp_failed", %{conn: conn} do
      {user, _secret} = create_owner_with_totp!()

      {:ok, view, _html} = live(conn, "/platform/login")
      submit_credentials(view, user.email, @password)

      html = submit_totp(view, "000000")

      assert html =~ "Invalid code"
      assert html =~ "platform-totp-form"

      assert [entry | _] = audit_entries(:totp_failed)
      assert entry.actor_id == user.id
    end

    test "a code cannot be reused within its window", %{conn: conn} do
      {user, secret} = create_owner_with_totp!()
      # Mark the current window as already used
      set_totp_last_used_at!(user, DateTime.utc_now())

      {:ok, view, _html} = live(conn, "/platform/login")
      submit_credentials(view, user.email, @password)

      html = submit_totp(view, NimbleTOTP.verification_code(secret))

      assert html =~ "Invalid code"
      assert html =~ "platform-totp-form"
    end

    test "more than 5 code attempts within a minute are rate limited", %{conn: conn} do
      {user, _secret} = create_owner_with_totp!()

      {:ok, view, _html} = live(conn, "/platform/login")
      submit_credentials(view, user.email, @password)

      for _ <- 1..5 do
        assert submit_totp(view, "000000") =~ "Invalid code"
      end

      html = submit_totp(view, "000000")
      refute html =~ "Invalid code"
      assert html =~ "Too many attempts"
    end

    test "back link returns to the credentials step", %{conn: conn} do
      {user, _secret} = create_owner_with_totp!()

      {:ok, view, _html} = live(conn, "/platform/login")
      submit_credentials(view, user.email, @password)

      html = view |> element("#totp-back") |> render_click()

      assert html =~ "platform-credentials-form"
      refute html =~ "platform-totp-form"
    end
  end

  describe "stale or missing pending state" do
    test "submitting a code without completing the password step resets to credentials",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/platform/login")

      html = render_submit(view, "submit_totp", %{"totp" => %{"code" => "000000"}})
      assert html =~ "platform-credentials-form"

      html = render_submit(view, "submit_totp_setup", %{"totp" => %{"code" => "000000"}})
      assert html =~ "platform-credentials-form"
    end

    test "staff deactivated between steps is reset to credentials", %{conn: conn} do
      {user, secret} = create_owner_with_totp!()
      # A second owner so EnsureOwnerRemains allows the deactivation
      create_platform_owner!()

      {:ok, view, _html} = live(conn, "/platform/login")
      submit_credentials(view, user.email, @password)

      user
      |> Ash.Changeset.for_update(:deactivate_staff, %{})
      |> Ash.update!(authorize?: false)

      html = submit_totp(view, NimbleTOTP.verification_code(secret))
      assert html =~ "platform-credentials-form"
      refute html =~ "platform-totp-form"
    end
  end

  describe "full first sign-in (end to end)" do
    test "password → TOTP enrolment → exchange → lands authenticated on /platform",
         %{conn: conn} do
      user = create_platform_owner!()

      {:ok, view, _html} = live(conn, "/platform/login")
      html = submit_credentials(view, user.email, @password)

      [base32] = extract_manual_secret(html)
      secret = Base.decode32!(base32, padding: false)

      submit_totp_setup(view, NimbleTOTP.verification_code(secret))
      {path, _flash} = assert_redirect(view)

      # Follow the exchange with a real cookie session (no init_test_session —
      # the test session adapter is not carried across recycled requests)
      conn = get(conn, path)
      assert redirected_to(conn) == "/platform"
      assert get_session(conn, :platform_session_token)

      {:ok, _view, html} = live(conn, "/platform")
      assert html =~ "Platform Overview"
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp submit_credentials(view, email, password) do
    view
    |> form("#platform-credentials-form", user: %{email: to_string(email), password: password})
    |> render_submit()
  end

  defp submit_totp(view, code) do
    view |> form("#platform-totp-form", totp: %{code: code}) |> render_submit()
  end

  defp submit_totp_setup(view, code) do
    view |> form("#platform-totp-setup-form", totp: %{code: code}) |> render_submit()
  end

  defp extract_manual_secret(html) do
    Regex.run(~r/id="totp-manual-secret"[^>]*>\s*([A-Z2-7]+)\s*</, html, capture: :all_but_first)
  end

  defp exchange_token_for(path) do
    assert path =~ "/platform/session?t="

    %URI{query: query} = URI.parse(path)
    %{"t" => token} = URI.decode_query(query)

    assert {:ok, user_id} = AuthTokens.verify_login_exchange(token)
    user_id
  end

  # Enrol TOTP, then backdate totp_last_used_at: setup_totp marks the
  # enrolment code as used, which would block a freshly minted code in the
  # same 30s window via the `since:` reuse guard.
  defp create_owner_with_totp! do
    user = create_platform_owner!()
    secret = TOTP.generate_secret()

    user
    |> Ash.Changeset.for_update(:setup_totp, %{
      secret: secret,
      code: NimbleTOTP.verification_code(secret)
    })
    |> Ash.update!(authorize?: false)

    set_totp_last_used_at!(user, DateTime.add(DateTime.utc_now(), -120, :second))

    {:ok, user} = Emakola.Accounts.get_user_by_id(user.id, authorize?: false)
    {user, secret}
  end

  defp set_totp_last_used_at!(user, datetime) do
    {1, _} =
      Emakola.Repo.update_all(
        from(u in "users", where: u.id == type(^user.id, :binary_id)),
        set: [totp_last_used_at: datetime]
      )

    :ok
  end

  defp audit_entries(action) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.read!(authorize?: false)
    |> Map.fetch!(:results)
    |> Enum.filter(&(&1.action == action))
  end
end
