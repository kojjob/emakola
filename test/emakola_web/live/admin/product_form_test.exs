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

      # Sellable by default — the default variant is untracked, so the product
      # is immediately purchasable without the merchant setting a stock count.
      assert [%{price: 2500, track_inventory: false}] = variants

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

  describe "Form — edit" do
    setup %{conn: conn} do
      {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, store: store}
    end

    test "plain edit: title change persisted, success flash shown, no error flash",
         %{conn: conn, store: store} do
      product = create_product!(store, %{title: "Old Title"})

      {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}/edit")

      {:ok, _rview, html} =
        view
        |> element("#product-form")
        |> render_submit(%{"product" => %{"title" => "New Title", "_action" => "draft"}})
        |> follow_redirect(conn)

      assert html =~ "Product saved successfully"
      updated = Ash.get!(Emakola.Catalog.Product, product.id, authorize?: false)
      assert updated.title == "New Title"
    end

    test "edit-rescue: draft with no variants → submit price 30.00 + activate → :active, one 3000-pesewa variant",
         %{conn: conn, store: store} do
      product = create_product!(store, %{title: "No-Variant Product"})

      {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}/edit")

      {:ok, _rview, html} =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{
            "title" => "No-Variant Product",
            "price" => "30.00",
            "_action" => "activate"
          }
        })
        |> follow_redirect(conn)

      assert html =~ "Product published"

      updated = Ash.get!(Emakola.Catalog.Product, product.id, authorize?: false)
      assert updated.status == :active

      variants =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(product_id == ^product.id)
        |> Ash.read!(authorize?: false)

      assert [%{price: 3000}] = variants
    end

    test "edit: product with variants + activate → :active status, published flash",
         %{conn: conn, store: store} do
      product = create_product!(store, %{title: "Has Variant"})
      _variant = create_variant!(product, store, %{price: 5000})

      {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}/edit")

      {:ok, _rview, html} =
        view
        |> element("#product-form")
        |> render_submit(%{"product" => %{"title" => "Has Variant", "_action" => "activate"}})
        |> follow_redirect(conn)

      assert html =~ "Product published"
      updated = Ash.get!(Emakola.Catalog.Product, product.id, authorize?: false)
      assert updated.status == :active
    end
  end

  describe "Form — cross-tenant access guard" do
    test "store B merchant mounting store A product edit URL gets redirected with flash",
         %{conn: conn} do
      {_ma, store_a} = create_merchant_with_store!()
      product_a = create_product!(store_a)

      {conn_b, _mb, _sb} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)

      assert {:error, {:redirect, %{to: "/admin/products", flash: flash}}} =
               live(conn_b, ~p"/admin/products/#{product_a.id}/edit")

      assert flash["error"] == "Product not found."
    end
  end

  describe "Form — zero/invalid price boundary" do
    setup %{conn: conn} do
      {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, store: store}
    end

    test "price '0' → no product created, error rendered",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      html =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Zero Price", "price" => "0", "_action" => "activate"}
        })

      assert html =~ "must be greater than 0.00"

      products =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert products == []
    end

    test "price '0.00' → no product created, error rendered",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      html =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Zero Price", "price" => "0.00", "_action" => "activate"}
        })

      assert html =~ "must be greater than 0.00"

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

    test "browse-files control renders the file input as a tappable overlay, not clipped sr-only",
         %{conn: conn} do
      # iOS Safari fails to open the file picker for an input that is hidden by
      # clipping it to 1px (`sr-only`) and triggered only through its wrapping
      # label. The input must instead be a full-size transparent overlay so the
      # tap lands on the <input type="file"> directly.
      {:ok, _view, html} = live(conn, ~p"/admin/products/new")
      input_tag = Regex.run(~r/<input[^>]*name="product_images"[^>]*>/, html) |> List.first()

      assert input_tag, "expected a product_images file input on the form"

      refute input_tag =~ "sr-only",
             "file input must not be hidden via clipped sr-only (iOS Safari won't open the picker)"

      assert input_tag =~ "opacity-0",
             "file input should be a transparent full-size tap overlay"
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

    test "storage error during upload → product saved, no crash, failure flash, no Image record",
         %{conn: conn, store: store} do
      stub(Emakola.StorageMock, :upload, fn _binary, _path, _opts -> {:error, :boom} end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/new")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      upload =
        file_input(view, "#product-form", :product_images, [
          %{name: "shirt.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "shirt.png")

      {:ok, _rview, html} =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Upload Fail", "price" => "10.00", "_action" => "draft"}
        })
        |> follow_redirect(conn)

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read_one!(authorize?: false)

      assert product != nil
      assert html =~ "Some images failed to upload"

      images =
        Emakola.Catalog.Image
        |> Ash.Query.filter(product_id == ^product.id)
        |> Ash.read!(authorize?: false)

      assert images == []
    end

    test "storage client RAISING during upload → product saved, no crash, failure flash",
         %{conn: conn, store: store} do
      # Regression: ExAws raised UndefinedFunctionError in production (missing
      # HTTP client) and crashed the upload channel — raises must be contained
      # like error tuples.
      stub(Emakola.StorageMock, :upload, fn _binary, _path, _opts ->
        raise "boom from storage client"
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/new")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      upload =
        file_input(view, "#product-form", :product_images, [
          %{name: "shirt.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "shirt.png")

      {:ok, _rview, html} =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Upload Raise", "price" => "10.00", "_action" => "draft"}
        })
        |> follow_redirect(conn)

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read_one!(authorize?: false)

      assert product != nil
      assert html =~ "Some images failed to upload"
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
