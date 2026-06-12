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

  describe "GET /auth/session with a signed subject" do
    test "establishes a session and redirects to dashboard", %{conn: conn} do
      {merchant, _store} = create_merchant_with_store!()
      signed = merchant |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

      conn = get(conn, "/auth/session?token=#{URI.encode_www_form(signed)}")

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_token) == signed

      # Follow-up request is authenticated
      assert {:ok, _view, _html} = live(conn, "/dashboard")
    end

    test "honours redirect_to", %{conn: conn} do
      user = create_user!()
      signed = user |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

      conn =
        get(conn, "/auth/session?token=#{URI.encode_www_form(signed)}&redirect_to=/onboarding")

      assert redirected_to(conn) == "/onboarding"
      assert get_session(conn, :user_token) == signed
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
