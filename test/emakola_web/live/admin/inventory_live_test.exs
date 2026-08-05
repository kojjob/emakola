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
        |> element("#inventory-search-form")
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
        |> element("#inventory-search-form")
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

    test "parses a decimal cost price into integer pesewas", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "COST-001"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      render_click(view, "edit_dropship", %{"id" => variant.id})

      view
      |> form("#dropship-form", %{
        variant: %{supplier_id: "", cost_price: "12.50", available: "true"}
      })
      |> render_submit()

      assert Ash.reload!(variant, authorize?: false).cost_price == 1250
    end

    test "parses a sub-cedi cost price without float rounding error", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "COST-002"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      render_click(view, "edit_dropship", %{"id" => variant.id})

      view
      |> form("#dropship-form", %{
        variant: %{supplier_id: "", cost_price: "0.01", available: "true"}
      })
      |> render_submit()

      assert Ash.reload!(variant, authorize?: false).cost_price == 1
    end

    test "rejects a supplier_id belonging to another store", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "SCOPE-001"})

      other_store = Factory.create_store!()
      foreign_supplier = Factory.create_supplier!(other_store, name: "Foreign Supplier")

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      render_click(view, "edit_dropship", %{"id" => variant.id})

      # Push a crafted payload directly — a malicious client can bypass the
      # store-scoped <select> and submit any supplier_id.
      html =
        render_submit(view, "save_dropship", %{
          "variant" => %{
            "supplier_id" => foreign_supplier.id,
            "cost_price" => "10.00",
            "available" => "true"
          }
        })

      assert html =~ "Invalid supplier"

      reloaded = Ash.reload!(variant, authorize?: false)
      assert is_nil(reloaded.supplier_id)
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

  describe "locations manager" do
    test "renders the locations section with the default location and badge", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      assert html =~ "Locations"
      assert html =~ "Main"
      assert html =~ "Default"
    end

    test "creates a location", %{conn: conn, store: store, merchant: merchant} do
      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      view
      |> element("button[phx-click='toggle_location_form']")
      |> render_click()

      html =
        view
        |> form("#add-location-form", %{"name" => "Market Stall"})
        |> render_submit()

      assert html =~ "Market Stall"

      {:ok, locations} = Emakola.Inventory.list_locations(merchant, store.id)
      assert Enum.any?(locations, &(&1.name == "Market Stall"))
    end

    test "renames a location", %{conn: conn, store: store, merchant: merchant} do
      main = Emakola.Inventory.ensure_default_location!(store.id)

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      render_click(view, "start_rename_location", %{"id" => main.id})

      html =
        view
        |> form("#rename-location-form", %{"name" => "Shop Floor"})
        |> render_submit()

      assert html =~ "Shop Floor"

      {:ok, locations} = Emakola.Inventory.list_locations(merchant, store.id)
      assert Enum.any?(locations, &(&1.name == "Shop Floor"))
      refute Enum.any?(locations, &(&1.name == "Main"))
    end

    test "sets a new default location", %{conn: conn, store: store, merchant: merchant} do
      Emakola.Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Emakola.Inventory.create_location(merchant, store.id, %{name: "Stall"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      view
      |> element("button[phx-click='set_default_location'][phx-value-id='#{stall.id}']")
      |> render_click()

      {:ok, [first | _]} = Emakola.Inventory.list_locations(merchant, store.id)
      assert first.id == stall.id
      assert first.default
    end

    test "deactivating the default location shows a friendly error", %{
      conn: conn,
      store: store
    } do
      main = Emakola.Inventory.ensure_default_location!(store.id)

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html = render_click(view, "deactivate_location", %{"id" => main.id})

      assert html =~ "The default location can&#39;t be deactivated"
    end

    test "deactivating a location that still holds stock shows a friendly error", %{
      conn: conn,
      store: store,
      merchant: merchant
    } do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "HOLD-001"})

      Emakola.Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Emakola.Inventory.create_location(merchant, store.id, %{name: "Stall"})
      {:ok, _} = Emakola.Inventory.restock(variant.id, stall.id, 5)

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("button[phx-click='deactivate_location'][phx-value-id='#{stall.id}']")
        |> render_click()

      assert html =~ "Move its stock first"

      {:ok, locations} = Emakola.Inventory.list_locations(merchant, store.id)
      assert Enum.find(locations, &(&1.id == stall.id)).active
    end

    test "deactivates an empty non-default location", %{
      conn: conn,
      store: store,
      merchant: merchant
    } do
      Emakola.Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Emakola.Inventory.create_location(merchant, store.id, %{name: "Stall"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      html =
        view
        |> element("button[phx-click='deactivate_location'][phx-value-id='#{stall.id}']")
        |> render_click()

      assert html =~ "Location deactivated"

      {:ok, locations} = Emakola.Inventory.list_locations(merchant, store.id)
      refute Enum.find(locations, &(&1.id == stall.id)).active
    end
  end

  describe "per-location breakdown" do
    test "shows a per-location breakdown on variant rows when the store has multiple locations",
         %{conn: conn, store: store, merchant: merchant} do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "BRK-001"})

      Emakola.Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Emakola.Inventory.create_location(merchant, store.id, %{name: "Stall"})
      {:ok, _} = Emakola.Inventory.restock(variant.id, stall.id, 4)

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      assert html =~ "Main 10"
      assert html =~ "Stall 4"
    end

    test "hides the breakdown when the store has a single location", %{
      conn: conn,
      store: store
    } do
      product = Factory.create_product!(store)
      _variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "SGL-001"})

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      refute html =~ "location-breakdown"
    end
  end

  describe "stock transfer" do
    test "transfers stock between locations", %{conn: conn, store: store, merchant: merchant} do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "TRF-001"})

      main = Emakola.Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Emakola.Inventory.create_location(merchant, store.id, %{name: "Stall"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      render_click(view, "open_transfer", %{"id" => variant.id})

      html =
        view
        |> form("#transfer-form", %{
          "transfer" => %{
            "from_location_id" => main.id,
            "to_location_id" => stall.id,
            "quantity" => "4"
          }
        })
        |> render_submit()

      assert html =~ "Stock transferred"

      levels = Emakola.Inventory.levels(variant.id)
      assert [%{quantity: 6}, %{quantity: 4}] = levels
      assert Enum.map(levels, & &1.location.name) == ["Main", "Stall"]

      assert Ash.reload!(variant, authorize?: false).stock_quantity == 10
    end

    test "transfer with insufficient source stock shows an error flash", %{
      conn: conn,
      store: store,
      merchant: merchant
    } do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "TRF-002"})

      main = Emakola.Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Emakola.Inventory.create_location(merchant, store.id, %{name: "Stall"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      render_click(view, "open_transfer", %{"id" => variant.id})

      html =
        view
        |> form("#transfer-form", %{
          "transfer" => %{
            "from_location_id" => main.id,
            "to_location_id" => stall.id,
            "quantity" => "25"
          }
        })
        |> render_submit()

      assert html =~ "Not enough stock at the source"
      assert Ash.reload!(variant, authorize?: false).stock_quantity == 10
    end
  end

  describe "stock editor with location picker" do
    test "saving the editor writes to the selected location", %{
      conn: conn,
      store: store,
      merchant: merchant
    } do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "EDIT-001"})

      main = Emakola.Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Emakola.Inventory.create_location(merchant, store.id, %{name: "Stall"})

      {:ok, view, _html} = live(conn, ~p"/admin/inventory")

      render_click(view, "start_edit", %{"id" => variant.id})

      view
      |> form("#stock-edit-form", %{"location_id" => stall.id, "stock" => "7"})
      |> render_submit()

      levels = Emakola.Inventory.levels(variant.id)
      assert %{quantity: 7} = Enum.find(levels, &(&1.location_id == stall.id))
      assert %{quantity: 10} = Enum.find(levels, &(&1.location_id == main.id))

      assert Ash.reload!(variant, authorize?: false).stock_quantity == 17
    end
  end

  describe "reserved-by-susu visibility (TC-3 Task 9)" do
    defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

    defp create_susu_plan!(store, attrs) do
      attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline())

      Emakola.Orders.SusuPlan
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
      |> Ash.create!(authorize?: false)
    end

    test "shows the reserved count for an active catalog plan's variant", %{
      conn: conn,
      store: store
    } do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "SUSU-001"})

      create_susu_plan!(store, %{
        type: :catalog,
        variant_id: variant.id,
        quantity: 3,
        total_amount: 5_000
      })
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      assert html =~ "Reserved by susu: 3"
    end

    test "does not show a reserved count for a pending or cancelled plan", %{
      conn: conn,
      store: store
    } do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "SUSU-002"})

      _pending =
        create_susu_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 4,
          total_amount: 5_000
        })

      cancelled =
        create_susu_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 4,
          total_amount: 5_000
        })

      cancelled |> Ash.Changeset.for_update(:cancel, %{}) |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      refute html =~ "Reserved by susu"
    end

    test "does not leak another store's reserved susu quantity", %{conn: conn, store: store} do
      product = Factory.create_product!(store)
      _variant = Factory.create_variant!(product, store, %{stock_quantity: 10, sku: "SUSU-003"})

      other_store = Factory.create_store!()
      other_product = Factory.create_product!(other_store)

      other_variant =
        Factory.create_variant!(other_product, other_store, %{
          stock_quantity: 10,
          sku: "OTHER-SUSU"
        })

      create_susu_plan!(other_store, %{
        type: :catalog,
        variant_id: other_variant.id,
        quantity: 7,
        total_amount: 5_000
      })
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/inventory")

      refute html =~ "Reserved by susu"
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
    subject = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn
    |> init_test_session(%{"user_token" => subject})
  end
end
