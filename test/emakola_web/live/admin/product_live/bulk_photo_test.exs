defmodule EmakolaWeb.Admin.ProductLive.BulkPhotoTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mox

  require Ash.Query

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

    test "tap-to-choose control renders the file input as a tappable overlay, not clipped sr-only",
         %{conn: conn} do
      # iOS Safari fails to open the file picker for a 1px `sr-only`-clipped
      # input triggered only through its wrapping label. The input must be a
      # full-size transparent overlay so the tap lands on it directly.
      {:ok, _view, html} = live(conn, "/admin/products/bulk")
      input_tag = Regex.run(~r/<input[^>]*name="photos"[^>]*>/, html) |> List.first()

      assert input_tag, "expected a photos file input on the bulk page"

      refute input_tag =~ "sr-only",
             "file input must not be hidden via clipped sr-only (iOS Safari won't open the picker)"

      assert input_tag =~ "opacity-0",
             "file input should be a transparent full-size tap overlay"
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

  describe "publish_all" do
    @png Base.decode64!(
           "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
         )

    setup :verify_on_exit!

    test "publishes complete cards as active products with priced variant + image",
         %{conn: conn, store: store} do
      stub(Emakola.StorageMock, :upload, fn _b, path, _o ->
        {:ok, "https://s3.example.com/#{path}"}
      end)

      {:ok, view, _html} = live(conn, "/admin/products/bulk")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      photos =
        file_input(view, "#bulk-photo-form", :photos, [
          %{name: "tomato.png", content: @png, type: "image/png"}
        ])

      render_upload(photos, "tomato.png")

      # Extract the entry ref from the remove button markup
      ref = view |> element("button[phx-click=remove_photo]") |> render() |> extract_ref()

      view |> render_hook("set_card", %{"ref" => ref, "field" => "name", "value" => "Tomatoes"})
      view |> render_hook("set_card", %{"ref" => ref, "field" => "price", "value" => "20"})

      view |> element("#bulk-photo-form") |> render_submit()

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id and title == "Tomatoes")
        |> Ash.read_one!(authorize?: false, load: [:variants, :images])

      assert product.status == :active
      assert [%{price: 2000, track_inventory: false}] = product.variants
      assert length(product.images) == 1
    end

    test "a card with no price is skipped and stays on the page",
         %{conn: conn, store: store} do
      stub(Emakola.StorageMock, :upload, fn _b, p, _o ->
        {:ok, "https://s3.example.com/#{p}"}
      end)

      {:ok, view, _html} = live(conn, "/admin/products/bulk")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      photos =
        file_input(view, "#bulk-photo-form", :photos, [
          %{name: "x.png", content: @png, type: "image/png"}
        ])

      render_upload(photos, "x.png")

      ref = view |> element("button[phx-click=remove_photo]") |> render() |> extract_ref()

      view
      |> render_hook("set_card", %{"ref" => ref, "field" => "name", "value" => "No Price Item"})

      html = view |> element("#bulk-photo-form") |> render_submit()

      assert html =~ "card_price"
      assert html =~ "No Price Item"

      assert Emakola.Catalog.Product
             |> Ash.Query.filter(store_id == ^store.id and title == "No Price Item")
             |> Ash.read!(authorize?: false) == []
    end
  end

  # Extracts the entry ref from the remove button's phx-value-ref attribute
  defp extract_ref(markup) do
    [_, ref] = Regex.run(~r/phx-value-ref="([^"]+)"/, markup)
    ref
  end
end
