defmodule EmakolaWeb.Auth.AuthTest do
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Emakola.Factory

  setup %{conn: conn} do
    # Use a unique remote_ip per test run to avoid Hammer rate limit collisions
    unique_ip = {10, 99, :rand.uniform(255), :rand.uniform(255)}
    {:ok, conn: %{conn | remote_ip: unique_ip}}
  end

  describe "Login page" do
    test "renders login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/login")
      assert html =~ "Welcome back"
      assert html =~ "Sign In"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    test "login with valid credentials redirects to session endpoint", %{conn: conn} do
      password = "Password123!"
      user = create_user!(password: password)

      {:ok, view, _html} = live(conn, "/auth/login")

      view
      |> form("form", user: %{email: to_string(user.email), password: password})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/auth/session"
      assert path =~ "token="
    end

    test "login with invalid credentials does not redirect", %{conn: conn} do
      create_user!(email: "test@example.com", password: "Password123!")

      {:ok, view, _html} = live(conn, "/auth/login")

      # Submit with wrong password - should not redirect, should stay on page
      view
      |> form("form", user: %{email: "test@example.com", password: "wrongpassword"})
      |> render_submit()

      # View should still be alive (no redirect happened)
      assert render(view) =~ "Welcome back"
    end

    test "login with nonexistent email does not redirect", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/auth/login")

      view
      |> form("form", user: %{email: "nonexistent@example.com", password: "Password123!"})
      |> render_submit()

      # View should still be alive (no redirect happened)
      assert render(view) =~ "Welcome back"
    end
  end

  describe "Registration page" do
    test "renders registration form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/register")
      assert html =~ "Create your account"
      assert html =~ "Create Account"
      assert html =~ "Full Name"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    test "registration with valid data redirects to session endpoint", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/auth/register")

      view
      |> form("form",
        user: %{
          name: "Test User",
          email: "newuser@example.com",
          password: "Password123!"
        }
      )
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/auth/session"
      assert path =~ "token="
      assert path =~ "redirect_to"
    end

    test "registration with duplicate email does not redirect", %{conn: conn} do
      existing = create_user!(email: "existing@example.com")

      {:ok, view, _html} = live(conn, "/auth/register")

      view
      |> form("form",
        user: %{
          name: "Another User",
          email: to_string(existing.email),
          password: "Password123!"
        }
      )
      |> render_submit()

      # Should stay on page (no redirect)
      assert render(view) =~ "Create your account"
    end

    test "registration does not create organisation (deferred to onboarding)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/auth/register")

      view
      |> form("form",
        user: %{
          name: "Org Creator",
          email: "orgcreator@example.com",
          password: "Password123!"
        }
      )
      |> render_submit()

      users =
        Emakola.Accounts.User
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&(to_string(&1.email) == "orgcreator@example.com"))

      assert length(users) == 1
      user = hd(users)

      memberships =
        Emakola.Accounts.Membership
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&(&1.user_id == user.id))

      assert memberships == []
    end
  end

  describe "Protected routes" do
    test "dashboard redirects to login when unauthenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end

    test "authenticated user can access dashboard", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, _view, html} = live(conn, "/dashboard")
      assert html =~ "Dashboard" or html =~ "dashboard"
    end
  end

  describe "Session management" do
    test "session controller creates session and redirects to dashboard", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/auth/session?token=#{URI.encode_www_form(token)}")

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_token) == token
    end

    test "session controller supports custom redirect_to", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/auth/session?token=#{URI.encode_www_form(token)}&redirect_to=/onboarding")

      assert redirected_to(conn) == "/onboarding"
    end

    test "logout clears session and redirects to login", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)
        |> delete("/auth/session")

      assert redirected_to(conn) == "/auth/login"
    end
  end

  describe "AssignDefaults hook" do
    test "loads current_user into dashboard layout", %{conn: conn} do
      user = create_user!()

      # Update user name via update_profile action
      user =
        user
        |> Ash.Changeset.for_update(:update_profile, %{name: "Ada Lovelace"})
        |> Ash.update!(authorize?: false)

      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, _view, html} = live(conn, "/dashboard")

      # The layout should show the user's name
      assert html =~ "Ada Lovelace"
    end

    test "sets current_user to nil when no token in session", %{conn: conn} do
      # Without auth, protected routes redirect to login
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end
  end
end
