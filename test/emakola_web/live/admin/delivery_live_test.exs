defmodule EmakolaWeb.Admin.DeliveryLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "DeliveryLive.Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/settings/delivery")
    end
  end

  describe "DeliveryLive.Index (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders delivery zones page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/settings/delivery")

      assert html =~ "Delivery Zones"
    end

    test "lists existing delivery zones", %{conn: conn, store: store} do
      Factory.create_delivery_zone!(store, name: "Greater Accra", fee: 1500)
      Factory.create_delivery_zone!(store, name: "Kumasi", fee: 2500)

      {:ok, _view, html} = live(conn, ~p"/admin/settings/delivery")

      assert html =~ "Greater Accra"
      assert html =~ "Kumasi"
    end

    test "can add a new delivery zone", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/delivery")

      # Open the form
      view |> element("[phx-click=\"show_form\"]") |> render_click()

      html =
        view
        |> form("#new-zone-form", %{
          zone: %{name: "Greater Accra", fee: "15.00", estimated_days: 1}
        })
        |> render_submit()

      assert html =~ "Greater Accra"
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
