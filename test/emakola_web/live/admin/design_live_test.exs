defmodule EmakolaWeb.Admin.DesignLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  defp log_in(conn, merchant) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "Homepage sections hand-off card" do
    test "renders for a store on a sectionized theme", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()

      store
      |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "starter"}})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(log_in(conn, merchant), "/admin/design")

      assert html =~ "Homepage sections"
      assert html =~ "/admin/design/sections"
    end

    # This test used to assert the OPPOSITE: Bold was the example of a theme
    # whose merchants got no card, because only Starter/Atelier/Market
    # implemented sections/0. The legacy retrofit (2026-07-13) sectionized the
    # last nine themes, so every theme in the lineup now offers the editor and
    # there is no real theme left to stand for the negative case.
    #
    # The card's gate (`Sections.sectionized?/1`) stays in place for any future
    # theme that ships without sections/0 — it is simply unreachable today.
    test "renders for a store on a legacy theme, now that those are sectionized too", %{
      conn: conn
    } do
      {merchant, store} = create_merchant_with_store!()

      store
      |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "bold"}})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(log_in(conn, merchant), "/admin/design")

      assert html =~ "Homepage sections"
      assert html =~ "/admin/design/sections"
    end
  end
end
