defmodule EmakolaWeb.ScreensTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  # ── Landing page ──────────────────────────────────────────────────

  describe "Landing page" do
    test "renders landing page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Makola"
    end
  end

  # ── Auth pages ────────────────────────────────────────────────────

  describe "Auth pages" do
    test "login page renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/login")
      assert html =~ "Sign In" or html =~ "Welcome back" or html =~ "Login"
    end

    test "register page renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/register")
      assert html =~ "Create" or html =~ "Register" or html =~ "Sign up"
    end
  end

  # ── App pages (auth-protected routes) ─────────────────────────────
  #
  # The RequireAuth hook redirects unauthenticated users to /auth/login
  # via push_navigate, which surfaces as {:error, {:live_redirect, ...}}.

  describe "App pages redirect unauthenticated users to login" do
    test "dashboard redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end
  end
end
