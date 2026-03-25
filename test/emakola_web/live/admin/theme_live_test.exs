defmodule EmakolaWeb.Admin.ThemeLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  describe "Theme customizer without store" do
    test "redirects to onboarding when no store", %{conn: conn} do
      user = create_user!(password: "Password123!")
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/onboarding"}}} = live(conn, ~p"/admin/theme")
    end
  end
end
