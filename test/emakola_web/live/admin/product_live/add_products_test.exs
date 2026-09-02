defmodule EmakolaWeb.Admin.ProductLive.AddProductsTest do
  @moduledoc """
  `/admin/products/new` is the photo-cards page: one photo or thirty, every
  photo becomes a card with a name and a price, and one button puts the
  finished cards in the shop. Designed for merchants who do not read well,
  so the page's state is carried by badges and counts, not sentences.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mox

  require Ash.Query

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup %{conn: conn} do
    {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  describe "start" do
    test "the new-product address opens on the camera, not a form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/products/new")

      assert html =~ "Add products"
      assert html =~ "Take a photo"
      assert html =~ "Choose photos"
      refute html =~ "SEO Title"
    end

    test "the typed form and the CSV upload stay one tap away", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products/new")

      assert has_element?(view, ~s{a[href="/admin/products/new/form"]}, "Type it in")
      assert has_element?(view, ~s{a[href="/admin/products?upload=csv"]}, "Upload a file")
    end

    test "the old bulk address still lands on the same page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/products/bulk")
      assert html =~ "Take a photo"
    end

    test "both photo inputs are full-size tap overlays, not clipped sr-only", %{conn: conn} do
      # iOS Safari will not open the picker for a clipped `sr-only` input
      # proxied by a label; the input itself must be under the thumb.
      {:ok, _view, html} = live(conn, "/admin/products/new")

      for name <- ["camera", "photos"] do
        input_tag = Regex.run(~r/<input[^>]*name="#{name}"[^>]*>/, html) |> List.first()
        assert input_tag, "expected a #{name} file input"
        refute input_tag =~ "sr-only"
        assert input_tag =~ "opacity-0"
      end

      camera_tag = Regex.run(~r/<input[^>]*name="camera"[^>]*>/, html) |> List.first()
      assert camera_tag =~ ~s(capture="environment")
    end
  end

  describe "cards" do
    test "every photo becomes a card, and the button counts what is ready", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products/new")
      upload_photos(view, ["a.png", "b.png"])

      html = render(view)
      assert html =~ "2 photos"
      assert length(String.split(html, ~s(name="card_name"))) - 1 == 2
      assert has_element?(view, "#publish-button[disabled]", "Put 0 in shop")
      assert html =~ "2 more need a name or price"
      assert has_element?(view, ~s{[data-state="untouched"]})
    end

    test "a photo taken with the camera is a card too", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products/new")

      camera = file_input(view, "#add-products-form", :camera, [png_upload("shot.png")])
      render_upload(camera, "shot.png")

      assert render(view) =~ "1 photo"
      assert has_element?(view, ~s{[id^="card-camera-"][data-state="untouched"]})
    end

    test "a card with a name and a price is ready; one missing a price is amber", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products/new")
      [ready_ref, half_ref] = upload_photos(view, ["ready.png", "half.png"])

      set_card(view, ready_ref, "name", "Fresh eggs")
      set_card(view, ready_ref, "price", "45")
      set_card(view, half_ref, "name", "Watermelon")

      assert has_element?(view, ~s{#card-photos-#{ready_ref}[data-state="ready"]})
      assert has_element?(view, ~s{#card-photos-#{half_ref}[data-state="incomplete"]})
      assert has_element?(view, ~s{#card-price-photos-#{half_ref}[data-missing]})
      refute has_element?(view, ~s{#card-name-photos-#{half_ref}[data-missing]})
      assert has_element?(view, "#publish-button:not([disabled])", "Put 1 in shop")
      assert render(view) =~ "1 more needs a name or price"
    end

    test "removing a photo drops its card", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products/new")
      [ref] = upload_photos(view, ["gone.png"])

      view |> render_hook("remove_photo", %{"upload" => "photos", "ref" => ref})

      refute has_element?(view, "#card-photos-#{ref}")
      assert render(view) =~ "Take a photo"
    end
  end

  describe "publish" do
    setup :verify_on_exit!

    test "ready cards become active products with a priced variant and their photo",
         %{conn: conn, store: store} do
      stub_storage()
      {:ok, view, _html} = live(conn, "/admin/products/new")
      Mox.allow(Emakola.StorageMock, self(), view.pid)
      [ref] = upload_photos(view, ["tomato.png"])

      set_card(view, ref, "name", "Tomatoes")
      set_card(view, ref, "price", "20")
      view |> element("#add-products-form") |> render_submit()

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id and title == "Tomatoes")
        |> Ash.read_one!(authorize?: false, load: [:variants, :images])

      assert product.status == :active
      assert [%{price: 2000, track_inventory: false}] = product.variants
      assert length(product.images) == 1
    end

    test "when every card is published the page shows the shop, not a redirect",
         %{conn: conn, store: store} do
      stub_storage()
      {:ok, view, _html} = live(conn, "/admin/products/new")
      Mox.allow(Emakola.StorageMock, self(), view.pid)
      [ref] = upload_photos(view, ["eggs.png"])

      set_card(view, ref, "name", "Fresh eggs")
      set_card(view, ref, "price", "45")
      html = view |> element("#add-products-form") |> render_submit()

      assert html =~ "1 in your shop"
      assert html =~ "Fresh eggs"
      assert html =~ "GH₵ 45"

      shop_url = EmakolaWeb.SEO.Canonical.store_url(store)
      assert has_element?(view, ~s{a[href="#{shop_url}"]}, "See my shop")

      view |> element("button", "Add more") |> render_click()
      assert render(view) =~ "Take a photo"
      refute render(view) =~ "in your shop"
    end

    test "a card with no price is skipped and stays on the page", %{conn: conn, store: store} do
      stub_storage()
      {:ok, view, _html} = live(conn, "/admin/products/new")
      Mox.allow(Emakola.StorageMock, self(), view.pid)
      [done_ref, half_ref] = upload_photos(view, ["done.png", "half.png"])

      set_card(view, done_ref, "name", "Oranges")
      set_card(view, done_ref, "price", "10")
      set_card(view, half_ref, "name", "No Price Item")
      html = view |> element("#add-products-form") |> render_submit()

      assert html =~ "No Price Item"
      assert has_element?(view, "#card-photos-#{half_ref}")
      refute has_element?(view, "#card-photos-#{done_ref}")

      assert Emakola.Catalog.Product
             |> Ash.Query.filter(store_id == ^store.id and title == "No Price Item")
             |> Ash.read!(authorize?: false) == []
    end

    test "nothing ready means nothing published", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/admin/products/new")
      upload_photos(view, ["blank.png"])

      html = view |> element("#add-products-form") |> render_submit()

      assert html =~ "Add a name and price to at least one product."

      assert Emakola.Catalog.Product
             |> Ash.Query.filter(store_id == ^store.id)
             |> Ash.read!(authorize?: false) == []
    end
  end

  describe "products index" do
    test "the header links to the new page, not the old bulk address", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products")

      assert has_element?(view, ~s{a[href="/admin/products/new"]}, "Add products")
      refute has_element?(view, ~s{a[href="/admin/products/bulk"]})
    end

    test "?upload=csv opens the CSV slide-over on arrival", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products?upload=csv")
      assert has_element?(view, "#bulk-upload-modal[phx-mounted]")

      {:ok, plain_view, _html} = live(conn, "/admin/products")
      refute has_element?(plain_view, "#bulk-upload-modal[phx-mounted]")
    end
  end

  # ── helpers ──

  defp png_upload(name), do: %{name: name, content: @png, type: "image/png"}

  # Uploads through the gallery input and returns the entry refs, in order.
  #
  # One test client per photo, on purpose: the test client stands in for the
  # browser's upload socket, and consuming one entry closes it, which would
  # drop every sibling entry it carried. A real browser keeps postponed
  # entries; separate clients give the test the same behaviour.
  defp upload_photos(view, names) do
    Enum.each(names, fn name ->
      photo = file_input(view, "#add-products-form", :photos, [png_upload(name)])
      render_upload(photo, name)
    end)

    ~r/id="card-photos-([^"]+)"/
    |> Regex.scan(render(view))
    |> Enum.map(fn [_, ref] -> ref end)
  end

  defp set_card(view, ref, field, value) do
    render_hook(view, "set_card", %{
      "upload" => "photos",
      "ref" => ref,
      "field" => field,
      "value" => value
    })
  end

  defp stub_storage do
    stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
      {:ok, "https://s3.example.com/#{path}"}
    end)
  end
end
