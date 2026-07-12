defmodule EmakolaWeb.Admin.ThemeLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory
  alias Emakola.Factory

  describe "Theme customizer without store" do
    test "redirects to onboarding when no store", %{conn: conn} do
      merchant = create_merchant!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/onboarding"}}} = live(conn, ~p"/admin/theme")
    end
  end

  describe "Theme customizer (authenticated merchant)" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders the 3-column customizer", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "Choose Your Look"
      assert html =~ "Themes"
      assert html =~ "Live Preview"
      assert html =~ "Colors"
      assert html =~ "Hero Banner"
      assert html =~ "Sections"

      # All 6 themes are listed as clickable buttons
      for theme_id <- ~w(market atelier vibrant starter bold fresh) do
        assert has_element?(view, "button[phx-value-theme-id=\"#{theme_id}\"]")
      end

      # All 8 color presets present (one per palette)
      for hex <- ~w(#CA8A04 #2563EB #DC2626 #059669 #7C3AED #DB2777 #EA580C #0D9488) do
        assert has_element?(view, "button[phx-value-hex=\"#{hex}\"]")
      end
    end

    test "every offerable theme is offered and no culled theme appears", %{conn: conn} do
      offerable = Emakola.Themes.ThemeResolver.offerable_theme_ids()
      culled = Emakola.Themes.ThemeResolver.culled_theme_ids()

      refute Enum.empty?(offerable), "no offerable themes — this test would be vacuous"

      refute Enum.empty?(culled),
             "no culled themes — the culled half of this test would be vacuous"

      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      for id <- offerable do
        assert has_element?(view, "button[phx-value-theme-id=\"#{id}\"]"),
               "theme #{inspect(id)} is offerable per ThemeResolver but the admin " <>
                 "picker does not offer it — add metadata to Admin.ThemeLive or cull " <>
                 "it in ThemeResolver.@culled_themes"
      end

      for id <- culled do
        refute has_element?(view, "button[phx-value-theme-id=\"#{id}\"]"),
               "theme #{inspect(id)} is culled but still offered in the admin picker"
      end
    end

    test "a crafted or culled theme-id is ignored, not persisted", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      # "akoma" is registered but culled; "totally-fake" is unregistered.
      # Neither is offered, so neither may be smuggled in via a crafted event.
      before_html = render(view)
      render_click(view, "select_theme", %{"theme-id" => "akoma"})
      render_click(view, "select_theme", %{"theme-id" => "totally-fake"})

      assert render(view) == before_html,
             "a crafted theme-id changed the admin customizer state"

      view |> element("button[phx-click=\"save_theme\"]") |> render_click()

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)

      refute get_in(reloaded.theme_config, ["theme"]) in ["akoma", "totally-fake"],
             "a crafted theme-id was written to the store: " <>
               inspect(get_in(reloaded.theme_config, ["theme"]))
    end

    test "hero image upload renders a tappable overlay input, not clipped sr-only", %{conn: conn} do
      # iOS Safari fails to open the file picker for a 1px sr-only-clipped input
      # triggered via a label. The input must be a full-size transparent overlay.
      {:ok, _view, html} = live(conn, ~p"/admin/theme")
      input_tag = Regex.run(~r/<input[^>]*name="hero_images"[^>]*>/, html) |> List.first()

      assert input_tag, "expected a hero_images file input on the theme page"

      refute input_tag =~ "sr-only",
             "file input must not be hidden via clipped sr-only (iOS Safari won't open the picker)"

      assert input_tag =~ "opacity-0",
             "file input should be a transparent full-size tap overlay"
    end

    test "select_theme switches active theme and applies palette from theme module", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      # Switch to "fresh" theme — assert against its real module defaults
      defaults = Emakola.Themes.Fresh.defaults()

      view
      |> element("button[phx-value-theme-id=\"fresh\"]")
      |> render_click()

      html = render(view)
      assert html =~ defaults.colors.primary
      assert html =~ defaults.colors.accent
      assert html =~ defaults.colors.background
    end

    test "theme picker cards show colors from theme module defaults (no hardcoded values)", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      # Each theme's picker card should display its actual primary color
      for {theme_id, mod} <- [
            {"market", Emakola.Themes.Market},
            {"atelier", Emakola.Themes.Atelier},
            {"vibrant", Emakola.Themes.Vibrant},
            {"fresh", Emakola.Themes.Fresh}
          ] do
        primary = mod.defaults().colors.primary
        assert html =~ primary, "expected theme #{theme_id} card to show its primary #{primary}"
      end
    end

    test "select_color updates the primary color via preset", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      view
      |> element("button[phx-value-hex=\"#DC2626\"]")
      |> render_click()

      assert render(view) =~ "#DC2626"
    end

    test "toggle_section flips the section flag and label", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      # Newsletter toggle starts ON
      assert view
             |> element("button[phx-value-section=\"newsletter\"][phx-click=\"toggle_section\"]")
             |> render() =~ "ON"

      view
      |> element("button[phx-value-section=\"newsletter\"][phx-click=\"toggle_section\"]")
      |> render_click()

      assert view
             |> element("button[phx-value-section=\"newsletter\"][phx-click=\"toggle_section\"]")
             |> render() =~ "OFF"
    end

    test "update_hero_title updates the hero title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      view
      |> element("input[name=\"hero_title\"]")
      |> render_change(%{"hero_title" => "Welcome to my store"})

      assert render(view) =~ "Welcome to my store"
    end

    test "update_hero_image updates the hero URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      view
      |> element("input[name=\"hero_image\"]")
      |> render_change(%{"hero_image" => "https://example.com/banner.jpg"})

      assert has_element?(view, "input[value=\"https://example.com/banner.jpg\"]")
    end

    test "save_theme persists colors and hero title to the store", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      # Pick a non-default color via preset, set a title, save
      view |> element("button[phx-value-hex=\"#7C3AED\"]") |> render_click()

      view
      |> element("input[name=\"hero_title\"]")
      |> render_change(%{"hero_title" => "Hand-roasted in Accra"})

      view |> element("button[phx-click=\"save_theme\"]") |> render_click()

      # Reload from DB and assert persisted config
      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      colors = get_in(reloaded.theme_config, ["colors"]) || %{}
      hero = get_in(reloaded.theme_config, ["hero"]) || %{}

      assert Map.get(colors, "primary") == "#7C3AED"
      assert Map.get(hero, "title") == "Hand-roasted in Accra"
    end

    test "save_theme persists the theme module's actual defaults (not hardcoded values)", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      vibrant_defaults = Emakola.Themes.Vibrant.defaults()

      # Switch to vibrant then save — its real palette should land in the DB
      view |> element("button[phx-value-theme-id=\"vibrant\"]") |> render_click()
      view |> element("button[phx-click=\"save_theme\"]") |> render_click()

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert get_in(reloaded.theme_config, ["theme"]) == "vibrant"

      assert get_in(reloaded.theme_config, ["colors", "primary"]) ==
               vibrant_defaults.colors.primary

      # LV reflects the saved palette — no market-blue (#2563EB) bleed
      assert render(view) =~ vibrant_defaults.colors.primary
    end

    test "save_theme persists section toggles", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/theme")

      # Turn off newsletter and trust
      view
      |> element("button[phx-value-section=\"newsletter\"][phx-click=\"toggle_section\"]")
      |> render_click()

      view
      |> element("button[phx-value-section=\"trust\"][phx-click=\"toggle_section\"]")
      |> render_click()

      view |> element("button[phx-click=\"save_theme\"]") |> render_click()

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      sections = get_in(reloaded.theme_config, ["sections"]) || %{}

      assert Map.get(sections, "newsletter") == false
      assert Map.get(sections, "trust") == false
      # Non-toggled sections stay on
      assert Map.get(sections, "hero") == true
    end
  end

  describe "Live preview uses real store data (no hardcoded values)" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "preview shows real category names instead of placeholder list", %{
      conn: conn,
      store: store
    } do
      Factory.create_category!(store, %{name: "Beans & Roasts"})
      Factory.create_category!(store, %{name: "Brew Gear"})

      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "Beans &amp; Roasts" or html =~ "Beans & Roasts"
      assert html =~ "Brew Gear"

      # The previously-hardcoded sample labels must NOT be in the preview
      refute html =~ "Coffee, Tea, Snacks, Spices"
    end

    test "preview shows empty-state hint when store has no categories", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ "Add categories to see them here"
    end

    test "preview newsletter copy is driven by theme config, not hardcoded", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      # The previous hardcoded "Stay in the know" must be gone
      refute html =~ "Stay in the know"
    end

    test "preview uses real store name and slug", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, ~p"/admin/theme")

      assert html =~ store.name
      assert html =~ "/s/#{store.slug}"
    end
  end
end
