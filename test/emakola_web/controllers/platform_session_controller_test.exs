defmodule EmakolaWeb.PlatformSessionControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.Sessions
  alias Emakola.Accounts.UserSession
  alias EmakolaWeb.AuthTokens

  setup %{conn: conn} do
    # Unique remote_ip per test to avoid Hammer rate limit collisions
    {:ok, conn: put_unique_peer_ip(conn)}
  end

  defp audit_entries(action) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.read!(authorize?: false)
    |> Map.fetch!(:results)
    |> Enum.filter(&(&1.action == action))
  end

  defp session_count do
    Ash.count!(UserSession, authorize?: false)
  end

  describe "GET /platform/session (exchange)" do
    test "valid exchange token creates a session, sets the cookie, and audits", %{conn: conn} do
      user = create_platform_owner!()
      t = AuthTokens.sign_login_exchange(user.id)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/platform/session?t=#{URI.encode_www_form(t)}")

      assert redirected_to(conn) == "/platform"

      signed = get_session(conn, :platform_session_token)
      assert {:ok, session_id} = AuthTokens.verify_platform_session(signed)
      assert {:ok, verified_user, session} = Sessions.verify_session_id(session_id)
      assert verified_user.id == user.id
      assert session.ip == format_ip(conn.remote_ip)

      assert [entry | _] = audit_entries(:sign_in_succeeded)
      assert entry.actor_id == user.id
      assert entry.ip == format_ip(conn.remote_ip)
    end

    test "records the request user agent on the session", %{conn: conn} do
      user = create_platform_owner!()
      t = AuthTokens.sign_login_exchange(user.id)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_req_header("user-agent", "PlatformTest/2.0")
        |> get("/platform/session?t=#{URI.encode_www_form(t)}")

      {:ok, session_id} =
        AuthTokens.verify_platform_session(get_session(conn, :platform_session_token))

      {:ok, _user, session} = Sessions.verify_session_id(session_id)
      assert session.user_agent == "PlatformTest/2.0"
    end

    test "tampered token creates no session and redirects to login", %{conn: conn} do
      user = create_platform_owner!()
      t = AuthTokens.sign_login_exchange(user.id) <> "x"

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/platform/session?t=#{URI.encode_www_form(t)}")

      assert redirected_to(conn) == "/platform/login"
      refute get_session(conn, :platform_session_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
      assert session_count() == 0
    end

    test "garbage token creates no session and redirects to login", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/platform/session?t=garbage")

      assert redirected_to(conn) == "/platform/login"
      refute get_session(conn, :platform_session_token)
      assert session_count() == 0
    end

    test "missing token redirects to login", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/platform/session")

      assert redirected_to(conn) == "/platform/login"
      refute get_session(conn, :platform_session_token)
    end

    test "rejects a deactivated staff user", %{conn: conn} do
      user =
        create_user!()
        |> Ash.Changeset.for_update(:set_platform_permissions, %{
          platform_permissions: [:manage_stores]
        })
        |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:deactivate_staff, %{})
        |> Ash.update!(authorize?: false)

      t = AuthTokens.sign_login_exchange(user.id)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/platform/session?t=#{URI.encode_www_form(t)}")

      assert redirected_to(conn) == "/platform/login"
      refute get_session(conn, :platform_session_token)
      assert session_count() == 0
    end

    test "rejects a plain (non-staff) user", %{conn: conn} do
      user = create_user!()
      t = AuthTokens.sign_login_exchange(user.id)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/platform/session?t=#{URI.encode_www_form(t)}")

      assert redirected_to(conn) == "/platform/login"
      refute get_session(conn, :platform_session_token)
      assert session_count() == 0
    end
  end

  describe "DELETE /platform/session (logout)" do
    test "revokes the session, clears the key, audits, and preserves the merchant session",
         %{conn: conn} do
      user = create_platform_owner!()
      {:ok, session} = Sessions.create(user, "10.0.0.1", "TestAgent/1.0")
      signed = AuthTokens.sign_platform_session(session.id)

      merchant = create_merchant!()

      merchant_token =
        EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:platform_session_token, signed)
        |> Plug.Conn.put_session(:user_token, merchant_token)
        |> delete("/platform/session")

      assert redirected_to(conn) == "/platform/login"
      refute get_session(conn, :platform_session_token)

      # Coexisting merchant session survives logout
      assert get_session(conn, :user_token) == merchant_token

      assert {:error, :revoked} = Sessions.verify_session_id(session.id)

      assert [entry | _] = audit_entries(:sign_out)
      assert entry.actor_id == user.id
    end

    test "logout without a platform session still redirects", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> delete("/platform/session")

      assert redirected_to(conn) == "/platform/login"
    end
  end

  defp format_ip(ip), do: ip |> :inet.ntoa() |> to_string()
end
