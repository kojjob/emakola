defmodule EmakolaWeb.Platform.SettingsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  defp log_in_platform_admin(conn) do
    admin = Factory.create_platform_admin!()
    token = AshAuthentication.user_to_subject(admin)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "access control" do
    test "platform admin can load the page", %{conn: conn} do
      conn = log_in_platform_admin(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "Settings"
      assert html =~ "feature flags"
    end

    test "a non-admin merchant is redirected", %{conn: conn} do
      {merchant, _store} = Factory.create_merchant_with_store!()
      token = AshAuthentication.user_to_subject(merchant)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/platform/settings")
    end
  end
end
