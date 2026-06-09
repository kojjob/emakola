defmodule EmakolaWeb.Admin.InventoryLiveTest do
  @moduledoc """
  LiveView tests for the admin inventory management dashboard.
  Tests stat cards, stock table, status filtering, search, and inline stock adjustment.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "InventoryLive page rendering" do
    test "renders page with stat cards", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Test Product"})
      _in_stock = Factory.create_variant!(product, store, %{stock_quantity: 50, sku: "SKU-A"})
      _low_stock = Factory.create_variant!(product, store, %{stock_quantity: 5, sku: "SKU-B"})
      _out_of_stock = Factory.create_variant!(product, store, %{stock_quantity: 0, sku: "SKU-C"})

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      assert html =~ "Inventory"
      assert html =~ "Total SKUs"
      assert html =~ "In Stock"
      assert html =~ "Low Stock"
      assert html =~ "Out of Stock"
      # 3 total variants
      assert html =~ "3"
    end

    test "displays variant table with product name and SKU", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Ankara Dress"})
      _variant = Factory.create_variant!(product, store, %{stock_quantity: 25, sku: "ANK-001"})

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      assert html =~ "Ankara Dress"
      assert html =~ "ANK-001"
      assert html =~ "25"
    end

    test "shows empty state when no variants", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      assert html =~ "No variants found"
    end

    test "shows correct stat counts", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      _v1 = Factory.create_variant!(product, store, %{stock_quantity: 20, sku: "S1"})
      _v2 = Factory.create_variant!(product, store, %{stock_quantity: 15, sku: "S2"})
      _v3 = Factory.create_variant!(product, store, %{stock_quantity: 3, sku: "S3"})
      _v4 = Factory.create_variant!(product, store, %{stock_quantity: 0, sku: "S4"})

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      # Total: 4, In Stock: 2, Low Stock: 1, Out of Stock: 1
      assert html =~ "4"
    end
  end

  describe "status filtering" do
    test "filters by in stock status", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      _in_stock = Factory.create_variant!(product, store, %{stock_quantity: 20, sku: "IN-STOCK"})

      _out_of_stock =
        Factory.create_variant!(product, store, %{stock_quantity: 0, sku: "OUT-STOCK"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("[phx-click='filter_status'][phx-value-status='in_stock']")
        |> render_click()

      assert html =~ "IN-STOCK"
      refute html =~ "OUT-STOCK"
    end

    test "filters by low stock status", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      _low = Factory.create_variant!(product, store, %{stock_quantity: 5, sku: "LOW-SKU"})
      _high = Factory.create_variant!(product, store, %{stock_quantity: 50, sku: "HIGH-SKU"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("[phx-click='filter_status'][phx-value-status='low_stock']")
        |> render_click()

      assert html =~ "LOW-SKU"
      refute html =~ "HIGH-SKU"
    end

    test "filters by out of stock status", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      _out = Factory.create_variant!(product, store, %{stock_quantity: 0, sku: "EMPTY-SKU"})
      _stocked = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "FULL-SKU"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("[phx-click='filter_status'][phx-value-status='out_of_stock']")
        |> render_click()

      assert html =~ "EMPTY-SKU"
      refute html =~ "FULL-SKU"
    end

    test "resets to show all variants", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      _v1 = Factory.create_variant!(product, store, %{stock_quantity: 0, sku: "ZERO"})
      _v2 = Factory.create_variant!(product, store, %{stock_quantity: 50, sku: "FIFTY"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      # First filter to out of stock
      view
      |> element("[phx-click='filter_status'][phx-value-status='out_of_stock']")
      |> render_click()

      # Then reset to all
      html =
        view
        |> element("[phx-click='filter_status'][phx-value-status='all']")
        |> render_click()

      assert html =~ "ZERO"
      assert html =~ "FIFTY"
    end
  end

  describe "search" do
    test "filters variants by product title", %{conn: conn, store: store} do
      product1 = Factory.create_product!(store, %{title: "Kente Cloth"})
      product2 = Factory.create_product!(store, %{title: "Ankara Fabric"})
      _v1 = Factory.create_variant!(product1, store, %{stock_quantity: 10, sku: "KC-001"})
      _v2 = Factory.create_variant!(product2, store, %{stock_quantity: 10, sku: "AF-001"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("form")
        |> render_change(%{"query" => "Kente"})

      assert html =~ "KC-001"
      refute html =~ "AF-001"
    end

    test "filters variants by SKU", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Test Product"})
      _v1 = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "UNIQUE-SKU-123"})
      _v2 = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "OTHER-456"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("form")
        |> render_change(%{"query" => "UNIQUE"})

      assert html =~ "UNIQUE-SKU-123"
      refute html =~ "OTHER-456"
    end
  end

  describe "stock adjustment" do
    test "increments stock by 1", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 5, sku: "ADJ-001"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("button[title='Increase by 1'][phx-value-id='#{variant.id}']")
        |> render_click()

      assert html =~ "6"
    end

    test "decrements stock by 1", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 5, sku: "ADJ-002"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("button[title='Decrease by 1'][phx-value-id='#{variant.id}']")
        |> render_click()

      assert html =~ "4"
    end

    test "displays stock status badges correctly", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      _in = Factory.create_variant!(product, store, %{stock_quantity: 20, sku: "BADGE-IN"})
      _low = Factory.create_variant!(product, store, %{stock_quantity: 5, sku: "BADGE-LOW"})
      _out = Factory.create_variant!(product, store, %{stock_quantity: 0, sku: "BADGE-OUT"})

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      assert html =~ "In Stock"
      assert html =~ "Low Stock"
      assert html =~ "Out of Stock"
    end
  end

  describe "dropship / supplier editing" do
    test "assigns a supplier, cost price and availability to a variant", %{
      conn: conn,
      store: store
    } do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "DROP-001"})
      supplier = Factory.create_supplier!(store, name: "Drop Supplier")

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      # Open the dropship editor for this variant.
      render_click(view, "edit_dropship", %{"id" => variant.id})

      view
      |> form("#dropship-form", %{
        variant: %{supplier_id: supplier.id, cost_price: "12.50", available: "true"}
      })
      |> render_submit()

      reloaded = Ash.reload!(variant, authorize?: false)
      assert reloaded.supplier_id == supplier.id
      assert reloaded.cost_price == 1250
      assert reloaded.available == true
      # Assigning a supplier disables inventory tracking.
      assert reloaded.track_inventory == false
    end

    test "shows a Dropshipped indicator for variants with a supplier", %{
      conn: conn,
      store: store
    } do
      product = Factory.create_product!(store)
      supplier = Factory.create_supplier!(store, name: "Indicator Supplier")

      Factory.create_variant!(product, store, %{
        stock_quantity: 5,
        sku: "IND-001",
        supplier_id: supplier.id
      })

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      assert html =~ "Dropshipped"
    end
  end

  describe "tenant isolation" do
    test "does not show variants from other stores", %{conn: conn, store: _store} do
      other_store = Factory.create_store!()
      other_product = Factory.create_product!(other_store, %{title: "Other Store Product"})

      _other_variant =
        Factory.create_variant!(other_product, other_store, %{
          stock_quantity: 100,
          sku: "OTHER-STORE-SKU"
        })

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      refute html =~ "OTHER-STORE-SKU"
      refute html =~ "Other Store Product"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/inventory")
    end
  end

  # ── Test Helpers ──

  defp create_authenticated_merchant! do
    uid = :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower, padding: false)

    store =
      Emakola.Stores.Store
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store #{uid}",
        slug: "test-store-#{uid}"
      })
      |> Ash.create!(authorize?: false)

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "merchant-#{uid}@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!(authorize?: false)

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!(authorize?: false)

    {merchant, store}
  end

  defp authenticate_conn(conn, merchant) do
    subject = AshAuthentication.user_to_subject(merchant)

    conn
    |> init_test_session(%{"user_token" => subject})
  end
end
