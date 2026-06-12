defmodule EmakolaWeb.Admin.ProductFormTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mox

  require Ash.Query

  import Emakola.Factory

  # Minimal 1×1 transparent PNG for upload tests
  @small_png Base.decode64!(
               "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
             )

  describe "Form — price field, variant creation, honest publish" do
    setup %{conn: conn} do
      {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, store: store}
    end

    # _action is on a <button name="product[_action]">, not an input/select/textarea,
    # so form/3 cannot resolve it. element + render_submit targets the form by
    # id="product-form" (still browser-faithful; fails if the id is absent).
    # Flash is a signed token in the live_redirect tuple; follow_redirect decodes it.
    test "creating with price + activate → active product, 2500-pesewas variant, storefront visible, published flash",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      {:ok, _redirect_view, html} =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Kente Cloth", "price" => "25.00", "_action" => "activate"}
        })
        |> follow_redirect(conn)

      assert html =~ "Product published"

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.status == :active

      variants =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(product_id == ^product.id)
        |> Ash.read!(authorize?: false)

      assert [%{price: 2500}] = variants

      active_products =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_by_store_and_status, %{
          store_id: store.id,
          status: :active
        })
        |> Ash.read!(authorize?: false)

      assert Enum.any?(active_products, &(&1.id == product.id))
    end

    test "activating without price → draft product, honest flash",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      {:ok, _redirect_view, html} =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Draft Product", "_action" => "activate"}
        })
        |> follow_redirect(conn)

      assert html =~ "Saved as draft"

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.status == :draft
    end

    test "invalid price → no product created, validation error rendered",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      html =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Ankara Print", "price" => "abc", "_action" => "activate"}
        })

      assert html =~ "must be a valid amount"

      products =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert products == []
    end
  end

  describe "Form — image upload" do
    setup %{conn: conn} do
      {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, store: store}
    end

    test "uploading an image on create → Image record linked to product",
         %{conn: conn, store: store} do
      stub(Emakola.StorageMock, :upload, fn _binary, _path, _opts ->
        {:ok, "https://s3.example.com/test/shirt.png"}
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/new")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      upload =
        file_input(view, "#product-form", :product_images, [
          %{name: "shirt.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "shirt.png")

      view
      |> element("#product-form")
      |> render_submit(%{
        "product" => %{"title" => "Image Product", "price" => "10.00", "_action" => "draft"}
      })

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read_one!(authorize?: false)

      assert product != nil

      images =
        Emakola.Catalog.Image
        |> Ash.Query.filter(product_id == ^product.id)
        |> Ash.read!(authorize?: false)

      assert length(images) == 1
      assert hd(images).url == "https://s3.example.com/test/shirt.png"
    end

    test "edit: existing image renders; delete_image removes it",
         %{conn: conn, store: store} do
      product = create_product!(store)
      image = create_image!(product, store)

      {:ok, view, html} = live(conn, ~p"/admin/products/#{product.id}/edit")

      assert html =~ image.url

      view
      |> element("[phx-click='delete_image'][phx-value-id='#{image.id}']")
      |> render_click()

      images =
        Emakola.Catalog.Image
        |> Ash.Query.filter(product_id == ^product.id)
        |> Ash.read!(authorize?: false)

      assert images == []
    end
  end
end
