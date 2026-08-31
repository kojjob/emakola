defmodule EmakolaWeb.Admin.ProductLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mox
  alias Emakola.Factory

  require Ash.Query

  describe "ProductLive.Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products")
    end
  end

  describe "first day" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "products can be narrowed to one category, and it composes with search", %{
      conn: conn,
      store: store
    } do
      shoes = Factory.create_category!(store, name: "Shoes")
      bags = Factory.create_category!(store, name: "Bags")
      Factory.create_product!(store, status: :active, title: "Red Sandal", category_id: shoes.id)
      Factory.create_product!(store, status: :active, title: "Blue Sandal", category_id: shoes.id)
      Factory.create_product!(store, status: :active, title: "Tote Bag", category_id: bags.id)

      {:ok, view, html} = live(conn, ~p"/admin/products")
      assert html =~ "Tote Bag"

      html = render_change(view, "filter_category", %{"category_id" => shoes.id})

      assert html =~ "Red Sandal"
      assert html =~ "Blue Sandal"
      refute html =~ "Tote Bag"

      # search narrows what the category already narrowed, rather than replacing it
      html = render_change(view, "search", %{"search" => "red"})

      assert html =~ "Red Sandal"
      refute html =~ "Blue Sandal"
    end

    test "an empty category says so rather than showing the whole catalogue", %{
      conn: conn,
      store: store
    } do
      empty = Factory.create_category!(store, name: "Hats")
      Factory.create_product!(store, status: :active, title: "Tote Bag")

      {:ok, view, _html} = live(conn, ~p"/admin/products")
      html = render_change(view, "filter_category", %{"category_id" => empty.id})

      refute html =~ "Tote Bag"
      assert html =~ "No products found"
    end

    test "a category filter that is not a uuid is ignored, not a crash", %{
      conn: conn,
      store: store
    } do
      Factory.create_product!(store, status: :active, title: "Tote Bag")

      {:ok, view, _html} = live(conn, ~p"/admin/products")
      html = render_change(view, "filter_category", %{"category_id" => "../../etc/passwd"})

      assert html =~ "Tote Bag"
    end

    test "a store with no products is told what to do, not that nothing was found", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      assert has_element?(view, "#product-empty-state", "Add your first product")

      # One obvious thing to do — the artboard's rule. The tour lives on
      # Customers, where there is no action to take yet.
      assert has_element?(view, "#product-empty-state a[href='/admin/products/new']") or
               has_element?(view, "#product-empty-state a[href='/admin/products/snap']")

      refute has_element?(view, "#product-empty-state a[href='/how-it-works/tour']")
    end

    test "the camera is offered as the first way in when AI is on", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      # Photo-first beats form-first for a merchant who reads slowly — and the
      # snap flow only exists when the AI key is configured.
      if EmakolaWeb.AiGate.enabled?() do
        assert has_element?(view, "#product-empty-state a[href='/admin/products/snap']")
      else
        refute has_element?(view, "#product-empty-state a[href='/admin/products/snap']")
      end
    end

    test "a search that matches nothing still says so", %{conn: conn, store: store} do
      Factory.create_product!(store, %{title: "Kente Scarf"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      html =
        view
        |> form("#product-search-form", %{"search" => "zzzznothing"})
        |> render_change()

      assert html =~ "No products found"
      refute html =~ "Add your first product"
    end
  end

  describe "ProductLive.Index (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders product list heading", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/products")

      assert html =~ "Products"
      assert has_element?(view, "button", "New Product")
    end

    test "caps the product list at 100 rows", %{conn: conn, store: store} do
      for i <- 1..101, do: Factory.create_product!(store, %{title: "Bulk Product #{i}"})

      {:ok, _view, html} = live(conn, ~p"/admin/products")

      # 1 header <tr> + 100 product rows
      assert length(String.split(html, "<tr")) - 1 == 101
    end

    test "renders status filter tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/products")

      assert html =~ "All"
      assert html =~ "Draft"
      assert html =~ "Active"
      assert html =~ "Archived"
    end

    test "renders search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      assert has_element?(view, "#product-search-form")
      assert has_element?(view, "input[name=\"search\"]")
    end
  end

  describe "ProductLive.Index redesign (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders KPI tiles with store-wide status counts", %{conn: conn, store: store} do
      Factory.create_product!(store, %{status: :active})
      Factory.create_product!(store, %{status: :active})
      Factory.create_product!(store)

      {:ok, view, html} = live(conn, ~p"/admin/products")

      assert html =~ "Total products"
      assert has_element?(view, "#stat-products-total", "3")
      assert has_element?(view, "#stat-products-active", "2")
      assert has_element?(view, "#stat-products-draft", "1")
      assert has_element?(view, "#stat-products-archived", "0")
    end

    test "filter tabs carry store-wide counts", %{conn: conn, store: store} do
      Factory.create_product!(store, %{status: :active})
      Factory.create_product!(store)
      Factory.create_product!(store, %{status: :archived})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      assert has_element?(view, "#products-filter-tabs button[phx-value-status=all]", "3")
      assert has_element?(view, "#products-filter-tabs button[phx-value-status=active]", "1")
      assert has_element?(view, "#products-filter-tabs button[phx-value-status=archived]", "1")
    end

    test "tab counts stay store-wide while the list filters", %{conn: conn, store: store} do
      Factory.create_product!(store, %{title: "Kente Scarf", status: :active})
      Factory.create_product!(store, %{title: "Draft Basket"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element("#products-filter-tabs button[phx-value-status=active]")
      |> render_click()

      assert has_element?(view, "#products-filter-tabs button[phx-value-status=all]", "2")
      assert render(view) =~ "Kente Scarf"
      refute render(view) =~ "Draft Basket"
    end

    test "product rows render a stock meter from variant stock", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Bolga Basket", status: :active})
      Factory.create_variant!(product, store, %{stock_quantity: 5, price: 1000})

      {:ok, _view, html} = live(conn, ~p"/admin/products")

      assert html =~ "bg-amber-500"
      assert html =~ ~r|>\s*5\s*</span>|
    end

    test "out-of-stock products read Out in the stock meter", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Shea Butter", status: :active})
      Factory.create_variant!(product, store, %{stock_quantity: 0, price: 1000})

      {:ok, _view, html} = live(conn, ~p"/admin/products")

      assert html =~ "Out"
      assert html =~ "bg-red-500"
    end
  end

  describe "ProductLive.Form (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products/new")
    end
  end

  describe "ProductLive.Form (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders new product form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/products/new")

      assert html =~ "New Product"
      assert html =~ "Title"
      assert html =~ "Save as Draft"
    end

    test "does not render the platform announcement banner", %{conn: conn} do
      {:ok, ann} =
        Emakola.Notifications.create_announcement(
          %{
            title: "Welcome to Makola Payouts",
            body: "You can now add your payout details.",
            channels: [:banner],
            audience: :all,
            publish_at: ~U[2026-06-20 00:00:00Z]
          },
          authorize?: false
        )

      {:ok, _} = Emakola.Notifications.publish_announcement(ann, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/products/new")

      refute html =~ "Welcome to Makola Payouts"
    end
  end

  describe "ProductLive.Form create (authenticated merchant)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    # Regression: form saves were silently denied after the H2 policy
    # tightening because create_product was called without authorize?: false.
    test "submitting the form creates a draft product", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      view
      |> element("form[phx-submit=\"save_product\"]")
      |> render_submit(%{"product" => %{"title" => "Bolga Basket", "description" => "Handwoven"}})

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id: store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.title == "Bolga Basket"
      assert product.status == :draft
    end
  end

  describe "ProductLive.Index edit (authenticated merchant)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    # Regression: open_edit_product crashed the LiveView with
    # Protocol.UndefinedError because get_product did not load :images,
    # and the slide-over template enumerates @editing_product.images.
    test "clicking Edit opens the slide-over with the product loaded",
         %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Kente Stole"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      html =
        view
        |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
        |> render_click()

      assert html =~ "Edit Product"
      assert html =~ "Kente Stole"
    end

    test "edit slide-over shows a price input per variant", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Adinkra Scarf"})
      variant = Factory.create_variant!(product, store, %{price: 15050, sku: "ADK-1"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      html =
        view
        |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
        |> render_click()

      assert html =~ "Pricing"
      assert html =~ "ADK-1"

      assert has_element?(
               view,
               ~s{input[name="product[variant_prices][#{variant.id}]"][value="150.50"]}
             )
    end

    # Regression: build_product_attrs always included :store_id, which the
    # product :update action does not accept — every edit save failed with
    # NoSuchInput and the form just showed an error flash.
    test "submitting the edit form updates the product", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Old Title"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
      |> render_click()

      view
      |> element("#product-slide-over-form")
      |> render_submit(%{"product" => %{"title" => "New Title"}})

      updated = Ash.get!(Emakola.Catalog.Product, product.id, authorize?: false)
      assert updated.title == "New Title"
    end

    test "submitting a changed price updates the variant", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Adinkra Scarf"})
      variant = Factory.create_variant!(product, store, %{price: 15050})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
      |> render_click()

      view
      |> element("#product-slide-over-form")
      |> render_submit(%{
        "product" => %{
          "title" => "Adinkra Scarf",
          "variant_prices" => %{variant.id => "200"}
        }
      })

      updated = Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
      assert updated.price == 20_000
    end

    test "an invalid price shows an error and does not save", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Adinkra Scarf"})
      variant = Factory.create_variant!(product, store, %{price: 15050})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
      |> render_click()

      html =
        view
        |> element("#product-slide-over-form")
        |> render_submit(%{
          "product" => %{
            "title" => "Adinkra Scarf",
            "variant_prices" => %{variant.id => "abc"}
          }
        })

      assert html =~ "must be a valid amount"

      unchanged = Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
      assert unchanged.price == 15_050
    end

    test "clicking Edit on a product with images shows the image grid",
         %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Fugu Smock"})
      image = Factory.create_image!(product, store)

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      html =
        view
        |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
        |> render_click()

      assert html =~ "Edit Product"
      assert html =~ (image.thumbnail_url || image.url)
    end
  end

  describe "ProductLive.Index slide-over create (authenticated merchant)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "creating with price and Save & Activate publishes the product",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element(~s{button[phx-click*="open_new_product"]})
      |> render_click()

      html =
        view
        |> element("#product-slide-over-form")
        |> render_submit(%{
          "product" => %{
            "title" => "Kente Cloth",
            "price" => "25.00",
            "_action" => "activate"
          }
        })

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id: store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.status == :active

      loaded = Ash.load!(product, [:variants], authorize?: false)
      assert [%{price: 2500}] = loaded.variants

      assert html =~ "Product published"
    end

    test "creating without price saves a draft and shows draft flash",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element(~s{button[phx-click*="open_new_product"]})
      |> render_click()

      html =
        view
        |> element("#product-slide-over-form")
        |> render_submit(%{
          "product" => %{
            "title" => "Kente Cloth",
            "_action" => "activate"
          }
        })

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id: store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.status == :draft
      assert html =~ "Saved as draft"
    end
  end

  describe "ProductLive.Index slide-over zero price boundary" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "slide-over price '0' → no product created, error rendered",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view |> element(~s{button[phx-click*="open_new_product"]}) |> render_click()

      html =
        view
        |> element("#product-slide-over-form")
        |> render_submit(%{
          "product" => %{"title" => "Zero", "price" => "0", "_action" => "activate"}
        })

      assert html =~ "must be greater than 0.00"

      products =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id: store.id)
        |> Ash.read!(authorize?: false)

      assert products == []
    end

    test "slide-over price '0.00' → no product created, error rendered",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view |> element(~s{button[phx-click*="open_new_product"]}) |> render_click()

      html =
        view
        |> element("#product-slide-over-form")
        |> render_submit(%{
          "product" => %{"title" => "Zero", "price" => "0.00", "_action" => "activate"}
        })

      assert html =~ "must be greater than 0.00"

      products =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id: store.id)
        |> Ash.read!(authorize?: false)

      assert products == []
    end
  end

  describe "ProductLive.Index delete_image cross-store guard" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "deleting a foreign-store image id via the event leaves it intact",
         %{conn: conn} do
      {_ma, store_a} = Factory.create_merchant_with_store!()
      product_a = Factory.create_product!(store_a)
      image_a = Factory.create_image!(product_a, store_a)

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      render_click(view, "delete_image", %{"id" => image_a.id})

      assert %Emakola.Catalog.Image{} =
               Ash.get!(Emakola.Catalog.Image, image_a.id, authorize?: false)
    end
  end

  describe "ProductLive.Index edit cross-store guard" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "a crafted edit id cannot open or update another store's product", %{conn: conn} do
      {_other_merchant, other_store} = Factory.create_merchant_with_store!()
      foreign_product = Factory.create_product!(other_store, %{title: "Foreign Product"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      render_click(view, "open_edit_product", %{"id" => foreign_product.id})

      refute has_element?(view, ~s{#pf_title[value="Foreign Product"]})

      assert Ash.get!(Emakola.Catalog.Product, foreign_product.id, authorize?: false).title ==
               "Foreign Product"
    end
  end

  describe "bulk CSV import with images" do
    @png Base.decode64!(
           "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
         )

    setup %{conn: conn} do
      {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, store: store}
    end

    setup :verify_on_exit!

    test "the bulk modal exposes an image drop zone and the new template header", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")
      html = render(view)
      assert html =~ "stock_quantity,tags,images"
      assert html =~ "Product images"
    end

    test "importing a CSV with a matched image publishes a product with that image",
         %{conn: conn, store: store} do
      stub(Emakola.StorageMock, :upload, fn _b, path, _o ->
        {:ok, "https://s3.example.com/#{path}"}
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/products")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      csv =
        Emakola.Catalog.CsvImporter.template_header() <>
          "\nOkra,Fresh,,OKRA-1,15,5,fresh,okra.png"

      file_input(view, "#csv-upload-form", :csv_file, [
        %{name: "p.csv", content: csv, type: "text/csv"}
      ])
      |> render_upload("p.csv")

      file_input(view, "#csv-upload-form", :bulk_images, [
        %{name: "okra.png", content: @png, type: "image/png"}
      ])
      |> render_upload("okra.png")

      view |> element("#csv-upload-form") |> render_submit()
      view |> element("button[phx-click=import_products]") |> render_click()

      p =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id and title == "Okra")
        |> Ash.read_one!(authorize?: false, load: [:images, :variants])

      assert p.status == :active
      assert [%{price: 1500}] = p.variants
      assert length(p.images) == 1
    end

    test "after import the preview is cleared (no accidental re-import)", %{
      conn: conn,
      store: store
    } do
      stub(Emakola.StorageMock, :upload, fn _b, path, _o ->
        {:ok, "https://s3.example.com/#{path}"}
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/products")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      csv = Emakola.Catalog.CsvImporter.template_header() <> "\nOkra,Fresh,,OKRA-1,15,5,fresh,"

      file_input(view, "#csv-upload-form", :csv_file, [
        %{name: "p.csv", content: csv, type: "text/csv"}
      ])
      |> render_upload("p.csv")

      view |> element("#csv-upload-form") |> render_submit()
      view |> element("button[phx-click=import_products]") |> render_click()

      # after import the preview is cleared — button is disabled, second click can't re-import
      assert has_element?(view, "button[phx-click=import_products][disabled]")

      count =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id and title == "Okra")
        |> Ash.read!(authorize?: false)
        |> length()

      assert count == 1
    end
  end
end
