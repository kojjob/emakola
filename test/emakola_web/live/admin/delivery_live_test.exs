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

    test "a negative zone fee is never stored", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/delivery")

      view |> element("[phx-click=\"show_form\"]") |> render_click()

      view
      |> form("#new-zone-form", %{
        zone: %{name: "Negative Zone", fee: "-5", estimated_days: 1}
      })
      |> render_submit()

      zones = Emakola.Shipping.list_delivery_zones!(store.id, authorize?: false)
      zone = Enum.find(zones, &(&1.name == "Negative Zone"))
      # The zone submit went through; the negative fee must not survive it.
      assert zone
      assert zone.fee >= 0
    end

    test "zone form renders free-above and per-kg pricing inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/delivery")

      html = view |> element("[phx-click=\"show_form\"]") |> render_click()

      assert html =~ "Free above"
      assert html =~ "Per kg fee"
      assert html =~ "zone[free_above]"
      assert html =~ "zone[per_kg_fee]"
    end

    test "saves free-above and per-kg values in pesewas", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/delivery")

      view |> element("[phx-click=\"show_form\"]") |> render_click()

      view
      |> form("#new-zone-form", %{
        zone: %{
          name: "Tiered Accra",
          fee: "15.00",
          estimated_days: 1,
          free_above: "200.00",
          per_kg_fee: "5.00"
        }
      })
      |> render_submit()

      zone =
        Emakola.Shipping.list_delivery_zones!(store.id, authorize?: false)
        |> Enum.find(&(&1.name == "Tiered Accra"))

      assert zone.fee == 1500
      assert zone.free_above_pesewas == 20_000
      assert zone.per_kg_fee_pesewas == 500
    end

    test "blank tier inputs leave the zone flat (ship-dark)", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/delivery")

      view |> element("[phx-click=\"show_form\"]") |> render_click()

      view
      |> form("#new-zone-form", %{
        zone: %{
          name: "Flat Accra",
          fee: "15.00",
          estimated_days: 1,
          free_above: "",
          per_kg_fee: ""
        }
      })
      |> render_submit()

      zone =
        Emakola.Shipping.list_delivery_zones!(store.id, authorize?: false)
        |> Enum.find(&(&1.name == "Flat Accra"))

      assert zone.fee == 1500
      assert zone.free_above_pesewas == nil
      assert zone.per_kg_fee_pesewas == nil
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
