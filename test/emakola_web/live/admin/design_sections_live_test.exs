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
  end
end
