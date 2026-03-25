defmodule EmakolaWeb.Admin.ThemeLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "ThemeLive (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/theme")
    end
  end

  describe "ThemeLive (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders theme page with drawer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "Theme Customizer"
      assert html =~ "theme-drawer"
      assert html =~ "Save Changes"
      assert html =~ "Reset to Default"
    end

    test "displays all three theme cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "Market"
      assert html =~ "Atelier"
      assert html =~ "Vibrant"
    end

    test "preview iframe references store slug", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "/s/#{store.slug}/"
      assert html =~ "preview-frame"
    end

    test "selecting a theme updates the active theme", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      html =
        view
        |> element("[phx-click=\"select_theme\"][phx-value-theme-id=\"atelier\"]")
        |> render_click()

      # Atelier theme card should now have the highlight ring
      assert html =~ "border-emerald-500"
      # Atelier default colors should be applied
      assert html =~ "#CA8A04"
    end

    test "save updates store theme_config", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      # Select atelier theme
      view
      |> element("[phx-click=\"select_theme\"][phx-value-theme-id=\"atelier\"]")
      |> render_click()

      # Save
      html =
        view
        |> element("[phx-click=\"save_theme\"]")
        |> render_click()

      assert html =~ "Saved!"

      # Verify store was updated
      updated_store = Ash.get!(Emakola.Accounts.Store, store.id)
      assert updated_store.theme_config["theme"] == "atelier"
    end

    test "toggle drawer hides and shows panel", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "translate-x-0"

      html =
        view
        |> element("[phx-click=\"toggle_drawer\"]")
        |> render_click()

      assert html =~ "translate-x-full"
    end

    test "toggle section toggles a section off and on", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      # Toggle hero off
      view
      |> element("[phx-click=\"toggle_section\"][phx-value-section=\"hero\"]")
      |> render_click()

      # Save to persist
      html =
        view
        |> element("[phx-click=\"save_theme\"]")
        |> render_click()

      assert html =~ "Saved!"
    end

    test "reset defaults restores theme defaults", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      # Select atelier then reset
      view
      |> element("[phx-click=\"select_theme\"][phx-value-theme-id=\"atelier\"]")
      |> render_click()

      html =
        view
        |> element("[phx-click=\"reset_defaults\"]")
        |> render_click()

      # Should still show atelier defaults
      assert html =~ "#CA8A04"
    end

    test "displays color inputs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "Primary"
      assert html =~ "Accent"
      assert html =~ "Background"
    end

    test "displays hero settings inputs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "Title"
      assert html =~ "Subtitle"
      assert html =~ "CTA Text"
    end

    test "displays section toggles", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "Hero"
      assert html =~ "Categories"
      assert html =~ "Featured Products"
      assert html =~ "Brand Story"
      assert html =~ "Instagram"
      assert html =~ "Newsletter"
    end
  end

  defp setup_authenticated_merchant(conn) do
    {merchant, store} = Factory.create_merchant_with_store!()
    token = AshAuthentication.user_to_subject(merchant)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
