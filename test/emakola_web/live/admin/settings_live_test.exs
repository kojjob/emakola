defmodule EmakolaWeb.Admin.SettingsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "SettingsLive (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/settings")
    end
  end

  describe "SettingsLive (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders settings page with store info", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, ~p"/admin/settings")

      assert html =~ "Settings"
      assert html =~ store.name
    end

    test "renders tab navigation", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/settings")

      assert html =~ "General"
      assert html =~ "Contact"
      assert html =~ "Delivery"
      assert html =~ "Notifications"
    end

    test "can update store name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html =
        view
        |> form("#general-form", %{store: %{name: "Updated Store Name"}})
        |> render_submit()

      assert html =~ "Settings saved"
    end

    test "can update tagline and cover image URL via General tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html =
        view
        |> form("#general-form", %{
          store: %{
            tagline: "Handmade with love in Accra",
            cover_image_url: "https://cdn.example.com/cover.jpg"
          }
        })
        |> render_submit()

      assert html =~ "Settings saved"
      assert html =~ "Handmade with love in Accra"
      assert html =~ "https://cdn.example.com/cover.jpg"
    end

    test "can update contact info", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      # Switch to contact tab
      view |> element("[phx-click=\"switch_tab\"][phx-value-tab=\"contact\"]") |> render_click()

      html =
        view
        |> form("#contact-form", %{
          store: %{
            contact_email: "test@example.com",
            contact_phone: "+233 24 123 4567"
          }
        })
        |> render_submit()

      assert html =~ "Settings saved"
    end
  end

  defp setup_authenticated_merchant(conn) do
    {merchant, store} = Factory.create_merchant_with_store!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
