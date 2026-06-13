defmodule EmakolaWeb.Admin.ProductLive.BulkPhotoTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  describe "mount" do
    test "renders the bulk photo page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/products/bulk")
      assert html =~ "Add many products"
      assert html =~ ~s(id="bulk-photo-form")
    end
  end

  describe "entry point" do
    test "products index links to the bulk photo page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products")
      assert has_element?(view, ~s{a[href="/admin/products/bulk"]})
    end
  end

  describe "photo cards" do
    @png Base.decode64!(
           "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
         )

    test "each uploaded photo becomes a card with name and price inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products/bulk")

      photos =
        file_input(view, "#bulk-photo-form", :photos, [
          %{name: "a.png", content: @png, type: "image/png"},
          %{name: "b.png", content: @png, type: "image/png"}
        ])

      render_upload(photos, "a.png")
      render_upload(photos, "b.png")

      # one card (name + price input) per photo
      assert view |> element("#bulk-photo-form") |> render() =~ "Price (GHS)"
      assert length(view |> render() |> String.split(~s(name="card_name"))) - 1 == 2
    end
  end
end
