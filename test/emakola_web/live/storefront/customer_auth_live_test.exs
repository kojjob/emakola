defmodule EmakolaWeb.Storefront.CustomerAuthLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Auth Test Store", slug: "auth-test", currency: "GHS"})
    %{store: store}
  end

  # -- Login Page --

  describe "CustomerLoginLive" do
    test "renders login form", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/login")

      assert html =~ "Sign in"
      assert html =~ "Email"
      assert html =~ "Password"
      assert html =~ store.name
    end

    test "has link to register page", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/login")

      assert html =~ "/s/#{store.slug}/register"
      assert html =~ "Create one"
    end

    test "has link to continue shopping", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/login")

      assert html =~ "/s/#{store.slug}"
      assert html =~ "Continue shopping"
    end

    test "shows error on invalid credentials", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/login")

      html =
        view
        |> form("#login-form", customer: %{email: "wrong@example.com", password: "badpassword"})
        |> render_submit()

      assert html =~ "Invalid email or password"
    end
  end

  # -- Register Page --

  describe "CustomerRegisterLive" do
    test "renders register form", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/register")

      assert html =~ "Create your account"
      assert html =~ "Email"
      assert html =~ "Password"
      assert html =~ "Confirm password"
      assert html =~ store.name
    end

    test "has link to login page", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/register")

      assert html =~ "/s/#{store.slug}/login"
      assert html =~ "Sign in"
    end

    test "has link to continue shopping", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/register")

      assert html =~ "/s/#{store.slug}"
      assert html =~ "Continue shopping"
    end

    test "shows name and phone as optional fields", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/register")

      assert html =~ "Name"
      assert html =~ "Phone"
      assert html =~ "optional"
    end
  end
end
