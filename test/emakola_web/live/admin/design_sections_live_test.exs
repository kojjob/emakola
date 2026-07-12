defmodule EmakolaWeb.Admin.DesignSectionsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Themes.HomeSections

  defp set_starter_theme!(store) do
    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "starter"}})
    |> Ash.update!(authorize?: false)
  end

  defp set_atelier_theme!(store) do
    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "atelier"}})
    |> Ash.update!(authorize?: false)
  end

  describe "without a store" do
    test "redirects to onboarding", %{conn: conn} do
      merchant = create_merchant!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/onboarding"}}} = live(conn, "/admin/design/sections")
    end
  end

  describe "with a starter-theme store" do
    setup %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      store = set_starter_theme!(store)
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "lists the active theme's sections in order", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/design/sections")
      assert html =~ "Hero"
      assert String.match?(html, ~r/Hero.*Category Pills.*Featured Products.*Trust.*Newsletter/s)
    end

    test "toggle + publish persists a disabled section", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(~s([phx-click="toggle_section"][phx-value-id="starter/newsletter"]))
      |> render_click()

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      assert %{"enabled" => false} = Enum.find(saved, &(&1["id"] == "starter/newsletter"))
    end

    test "move down then publish persists the order", %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(
        ~s([phx-click="move_section"][phx-value-id="starter/hero"][phx-value-dir="down"])
      )
      |> render_click()

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      assert ["starter/category_pills", "starter/hero" | _] = Enum.map(saved, & &1["id"])
    end

    test "an unrecognized move direction leaves the order unchanged", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html = render_click(view, "move_section", %{"id" => "starter/hero", "dir" => "sideways"})

      assert String.match?(html, ~r/Hero.*Category Pills.*Featured Products.*Trust.*Newsletter/s)
    end

    test "the unsaved-changes guard is mounted and its dirty flag tracks the draft", %{conn: conn} do
      {:ok, view, html} = live(conn, "/admin/design/sections")

      assert html =~ ~s(phx-hook="UnsavedChanges")
      assert html =~ ~s(data-dirty="false")

      dirty_html =
        view
        |> element(~s([phx-click="toggle_section"][phx-value-id="starter/newsletter"]))
        |> render_click()

      assert dirty_html =~ ~s(data-dirty="true")
    end

    test "the first section's move-up control is disabled", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      assert view
             |> element(
               ~s(button[phx-click="move_section"][phx-value-id="starter/hero"][phx-value-dir="up"][disabled])
             )
             |> has_element?()
    end

    test "reset clears the saved layout", %{conn: conn, merchant: merchant, store: store} do
      {:ok, _} = HomeSections.put_layout(merchant, store, "starter", [])
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view |> element(~s(button[phx-click="reset_layout"])) |> render_click()

      assert HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter") == nil
    end

    test "preview reflects the draft immediately (no publish)", %{conn: conn} do
      {:ok, view, html} = live(conn, "/admin/design/sections")
      assert html =~ ~s(data-section-id="starter/newsletter")

      view
      |> element(~s([phx-click="toggle_section"][phx-value-id="starter/newsletter"]))
      |> render_click()

      refute render(view) =~ ~s(data-section-id="starter/newsletter")
    end

    test "an unresolvable saved section type renders as a disabled missing-section row instead of crashing",
         %{conn: conn, store: store} do
      store
      |> Ash.Changeset.for_update(:update, %{
        theme_config: %{
          "theme" => "starter",
          "home_sections" => %{
            "v" => 1,
            "starter" => [
              %{
                "id" => "starter/ghost",
                "type" => "starter/ghost",
                "enabled" => true,
                "settings" => %{},
                "style" => %{}
              }
            ]
          }
        }
      })
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/admin/design/sections")

      assert html =~ "Missing section"
      refute html =~ "phx-click=\"toggle_section\" phx-value-id=\"starter/ghost\""
    end

    test "editing a setting persists through publish", %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(~s(form[phx-change="update_settings"][phx-value-id="starter/hero"]))
      |> render_change(%{
        "settings" => %{"heading" => "Big Sale", "subheading" => "", "cta_label" => ""}
      })

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")

      assert %{"settings" => %{"heading" => "Big Sale"}} =
               Enum.find(saved, &(&1["id"] == "starter/hero"))
    end

    test "editing style controls persists through publish", %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(~s(form[phx-change="update_style"][phx-value-id="starter/hero"]))
      |> render_change(%{"style" => %{"bg" => "#112233", "text" => "#ffffff", "padding" => "lg"}})

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")

      assert %{"style" => %{"bg" => "#112233", "text" => "#ffffff", "padding" => "lg"}} =
               Enum.find(saved, &(&1["id"] == "starter/hero"))
    end

    test "add a bridged block section and publish", %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(~s([phx-click="add_section"][phx-value-type="block/text_section"]))
      |> render_click()

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      assert Enum.any?(saved, &(&1["type"] == "block/text_section"))
    end

    test "adding a block section appears immediately in the draft rail and the live preview",
         %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/text_section"]))
        |> render_click()

      assert html =~ "Builder block"
      assert html =~ ~s(data-section-id="block/text_section-)
    end

    test "default theme sections have no remove control", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/design/sections")
      refute html =~ ~s(phx-click="remove_section" phx-value-id="starter/hero")
    end

    test "a custom block instance has a remove control that deletes it from the draft and publish",
         %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      add_html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/text_section"]))
        |> render_click()

      [_, id] = Regex.run(~r/phx-value-id="(block\/text_section-\d+)"/, add_html)

      assert view
             |> element(~s([phx-click="remove_section"][phx-value-id="#{id}"]))
             |> has_element?()

      view |> element(~s([phx-click="remove_section"][phx-value-id="#{id}"])) |> render_click()

      refute view
             |> element(~s([phx-click="remove_section"][phx-value-id="#{id}"]))
             |> has_element?()

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      refute Enum.any?(saved, &(&1["id"] == id))
    end

    test "attempting to remove a default section via a crafted event is a no-op", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html = render_click(view, "remove_section", %{"id" => "starter/hero"})
      assert html =~ "Hero"
    end

    test "the add-section picker groups theme sections and content blocks", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/design/sections")

      assert html =~ "Theme sections"
      assert html =~ "Content blocks"
      assert html =~ ~s(phx-click="add_section" phx-value-type="starter/hero")
      assert html =~ ~s(phx-click="add_section" phx-value-type="block/text_section")
    end

    test "add a product_grid block, edit its integer setting, and publish", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      add_html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/product_grid"]))
        |> render_click()

      [_, id] = Regex.run(~r/phx-value-id="(block\/product_grid-\d+)"/, add_html)

      view
      |> element(~s(form[phx-change="update_settings"][phx-value-id="#{id}"]))
      |> render_change(%{"settings" => %{"count" => "3"}})

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      entry = Enum.find(saved, &(&1["id"] == id))
      assert entry["settings"]["count"] == 3
    end

    test "clearing a block's integer setting falls back to its default rather than crashing the preview",
         %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      add_html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/product_grid"]))
        |> render_click()

      [_, id] = Regex.run(~r/phx-value-id="(block\/product_grid-\d+)"/, add_html)

      html =
        view
        |> element(~s(form[phx-change="update_settings"][phx-value-id="#{id}"]))
        |> render_change(%{"settings" => %{"count" => ""}})

      assert Process.alive?(view.pid)
      assert html =~ "Builder block"
    end

    test "an unrecognized event is logged and does not crash the view", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          render_click(view, "some_theme_hook_event", %{"foo" => "bar"})
        end)

      assert log =~ "unhandled event"
      assert Process.alive?(view.pid)
      assert render(view) =~ "Hero"
    end
  end

  describe "preview interactivity guard (Atelier)" do
    setup %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      store = set_atelier_theme!(store)

      # Atelier's featured_products puts the FIRST product in a
      # hero_product_card and only the rest through product_card/1 — the
      # component that carries phx-click="add_to_cart". Several products
      # are needed for the dangerous markup to appear at all.
      for _ <- 1..3, do: create_product!(store, %{status: :active})

      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    # The preview renders REAL theme markup, which carries live bindings the
    # editor has no handlers for — Atelier's product_card/1 ships
    # phx-click="add_to_cart" and is rendered by the default-enabled
    # featured_products section. Without a guard, a merchant clicking a
    # preview product raises FunctionClauseError in handle_event/3, the
    # LiveView crashes, and the draft (socket assigns only, by design) is
    # silently destroyed. The guard is pointer-events on the content wrapper
    # — theme-agnostic, so it covers the upcoming themes too.
    test "the preview content wrapper is non-interactive, and it is the guard — not missing markup — that protects the draft",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/design/sections")

      # The dangerous markup really is rendered...
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ "atelier-product-card"

      # ...and the wrapper around the rendered sections neutralises it —
      # pointer-events for the mouse, inert for the keyboard (a merchant
      # could otherwise Tab to the button and press Enter).
      assert html =~ "section-preview-content"
      assert html =~ "pointer-events-none"
      assert html =~ "inert"
    end

    test "the panel's own chrome stays interactive", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/design/sections")

      # The guard must sit on the preview CONTENT, not the whole panel —
      # the editor's own controls must keep working.
      assert view
             |> element(~s([phx-click="toggle_section"][phx-value-id="atelier/newsletter"]))
             |> has_element?()
    end
  end
end

defmodule EmakolaWeb.Admin.DesignSectionsLiveSanitizationTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (a
  # test-only seam shared with Sections.resolve/1 — see
  # Emakola.Themes.SectionRendererTest) to exercise a section whose schema
  # actually declares an :image_url setting. None of Starter/Atelier's real
  # sections do yet, so the round-trip-honesty behavior (a rejected
  # `javascript:` URL comes back cleared after publish) can't be proven
  # against them. Must not run async — a separate module (not a describe
  # block) so the rest of the file keeps running async: true.
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Themes.HomeSections

  defmodule PhotoSection do
    @behaviour Emakola.Themes.Section
    use Phoenix.Component

    def key, do: "extra/photo"
    def label, do: "Photo"

    def settings_schema,
      do: [%{key: "photo_url", type: :image_url, label: "Photo URL", default: ""}]

    def render(assigns) do
      ~H"""
      <section data-sec="photo">{@settings["photo_url"]}</section>
      """
    end
  end

  defmodule FakeExtensionTheme do
    def id, do: "extra"
    def sections, do: [PhotoSection]
  end

  setup %{conn: conn} do
    Application.put_env(:emakola, :extra_sectionized_themes, [FakeExtensionTheme])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)

    {merchant, store} = create_merchant_with_store!()

    store =
      store
      |> Ash.Changeset.for_update(:update, %{
        theme_config: %{
          "theme" => "starter",
          "home_sections" => %{
            "v" => 1,
            "starter" => [
              %{
                "id" => "extra/photo",
                "type" => "extra/photo",
                "enabled" => true,
                "settings" => %{},
                "style" => %{}
              }
            ]
          }
        }
      })
      |> Ash.update!(authorize?: false)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store}
  end

  test "a javascript: URL in an :image_url setting is dropped at publish, the reloaded draft shows it cleared, and the flash notes the drop",
       %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, "/admin/design/sections")

    view
    |> element(~s(form[phx-change="update_settings"][phx-value-id="extra/photo"]))
    |> render_change(%{"settings" => %{"photo_url" => "javascript:alert(1)"}})

    html = view |> element(~s(button[phx-click="publish"])) |> render_click()

    saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
    entry = Enum.find(saved, &(&1["id"] == "extra/photo"))
    refute Map.has_key?(entry["settings"], "photo_url")

    assert html =~ "dropped"
  end
end
