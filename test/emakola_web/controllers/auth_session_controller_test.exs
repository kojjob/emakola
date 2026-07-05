defmodule EmakolaWeb.AuthSessionControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias EmakolaWeb.AuthTokens

  describe "GET /auth/session with a raw (unsigned) subject" do
    test "does not establish a session", %{conn: conn} do
      user = create_user!()
      raw_subject = AshAuthentication.user_to_subject(user)

      conn = get(conn, "/auth/session?token=#{URI.encode_www_form(raw_subject)}")

      assert redirected_to(conn) == "/auth/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
      refute get_session(conn, :user_token)

      # Follow-up request is unauthenticated
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end

    test "does not establish a session for a merchant subject", %{conn: conn} do
      {merchant, _store} = create_merchant_with_store!()
      raw_subject = AshAuthentication.user_to_subject(merchant)

      conn = get(conn, "/auth/session?token=#{URI.encode_www_form(raw_subject)}")

      assert redirected_to(conn) == "/auth/login"
      refute get_session(conn, :user_token)
    end
  end

  describe "GET /auth/session with a short-lived exchange token" do
    test "establishes a session and redirects to dashboard", %{conn: conn} do
      {merchant, _store} = create_merchant_with_store!()
      subject = AshAuthentication.user_to_subject(merchant)
      exchange = AuthTokens.sign_subject_exchange(subject)

      conn = get(conn, "/auth/session?token=#{URI.encode_www_form(exchange)}")

      assert redirected_to(conn) == "/dashboard"

      # The session holds a freshly-minted LONG-lived token — not the URL token.
      session_token = get_session(conn, :user_token)
      assert session_token != exchange
      assert {:ok, ^subject} = AuthTokens.verify_subject(session_token)

      # Follow-up request is authenticated
      assert {:ok, _view, _html} = live(conn, "/dashboard")
    end

    test "honours redirect_to", %{conn: conn} do
      user = create_user!()
      exchange = user |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject_exchange()

      conn =
        get(conn, "/auth/session?token=#{URI.encode_www_form(exchange)}&redirect_to=/onboarding")

      assert redirected_to(conn) == "/onboarding"
      assert get_session(conn, :user_token)
    end

    test "rejects a long-lived session token passed in the URL", %{conn: conn} do
      user = create_user!()
      # A leaked durable session token must NOT be replayable via the URL bridge.
      session_token = user |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

      conn = get(conn, "/auth/session?token=#{URI.encode_www_form(session_token)}")

      assert redirected_to(conn) == "/auth/login"
      refute get_session(conn, :user_token)
    end
  end

  describe "GET /auth/session with garbage or missing token" do
    test "garbage token redirects to login without session write", %{conn: conn} do
      conn = get(conn, "/auth/session?token=garbage")

      assert redirected_to(conn) == "/auth/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
      refute get_session(conn, :user_token)
    end

    test "missing token redirects to login", %{conn: conn} do
      conn = get(conn, "/auth/session")

      assert redirected_to(conn) == "/auth/login"
      refute get_session(conn, :user_token)
    end
  end
end
