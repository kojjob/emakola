defmodule EmakolaWeb.Admin.PageLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "PageLive.Form block media upload" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    # Regression: the :block_media accept list contained .m4a and .ogg, which
    # have no MIME mapping — allow_upload raised at mount and the page editor
    # crashed for every merchant.
    test "renders the new page editor", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/pages/new")

      assert html =~ "Add block"
    end

    test "block media uploads to platform storage, not local disk", %{conn: conn} do
      Mox.stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
        {:ok, "https://cdn.example.com/#{path}"}
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/pages/new")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      render_click(view, "add_block", %{"type" => "image_banner"})

      media =
        file_input(view, "form[phx-submit=save_block_media]", :block_media, [
          %{name: "banner.png", content: <<137, 80, 78, 71>>, type: "image/png"}
        ])

      render_upload(media, "banner.png")

      html =
        view
        |> element("form[phx-submit=save_block_media]")
        |> render_submit()

      assert html =~ "https://cdn.example.com/stores/"
    end
  end
end
