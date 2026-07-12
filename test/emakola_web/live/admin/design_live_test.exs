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

    # Only Starter/Atelier/Market implement sections/0 — for every other
    # theme the section editor redirects away, so the card must not render a
    # link that goes nowhere.
    test "does not render for a store on a non-sectionized theme", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()

      store
      |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "bold"}})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(log_in(conn, merchant), "/admin/design")

      refute html =~ "Homepage sections"
      refute html =~ "/admin/design/sections"
    end
  end
end
