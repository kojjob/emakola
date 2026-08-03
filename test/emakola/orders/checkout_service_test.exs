defmodule Emakola.Orders.CheckoutServiceTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  alias Emakola.Suppliers.{ListingImporter, Network, Offers}

  setup do
    store = create_store!()
    product = create_product!(store, title: "Kente Cloth")
    variant = create_variant!(product, store, price: 25_000, sku: "KC-001", stock_quantity: 10)
    customer = create_customer!(store, email: "checkout@example.com", name: "Kwame Checkout")
    {:ok, store: store, product: product, variant: variant, customer: customer}
  end

  # -- Successful checkout --------------------------------------------

  describe "successful checkout" do
    test "single item checkout", %{store: store, variant: variant, customer: customer} do
      items = [%{variant_id: variant.id, quantity: 2}]
      opts = [customer_id: customer.id]

      assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, opts)

      assert order.store_id == store.id
      assert order.customer_id == customer.id
      assert order.status == :pending
      assert order.subtotal == 50_000
      assert order.total == 50_000
      assert order.currency == "GHS"
      assert order.order_number
    end

    test "multi-item checkout", %{store: store, product: product, customer: customer} do
      variant1 = create_variant!(product, store, price: 10_000, sku: "V1", stock_quantity: 20)
      variant2 = create_variant!(product, store, price: 5_000, sku: "V2", stock_quantity: 15)

      items = [
        %{variant_id: variant1.id, quantity: 3},
        %{variant_id: variant2.id, quantity: 2}
      ]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items, customer_id: customer.id)

      assert order.subtotal == 40_000
      assert order.total == 40_000

      line_items =
        order
        |> Ash.load!(:line_items, authorize?: false)
        |> Map.get(:line_items)

      assert length(line_items) == 2
    end

    test "checkout reserves no stock; payment confirmation decrements it",
         %{store: store, variant: variant} do
      items = [%{variant_id: variant.id, quantity: 3}]

      assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

      # Still 10 — an unpaid order holds no stock, so abandonment never bleeds it.
      assert Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false).stock_quantity == 10

      # Confirming the order (payment success) is what decrements stock.
      {:ok, _} = Emakola.Orders.confirm_order(order, authorize?: false)
      assert Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false).stock_quantity == 7
    end

    test "an abandoned (never-confirmed) order leaves stock intact",
         %{store: store, variant: variant} do
      assert {:ok, _order} =
               Emakola.Orders.CheckoutService.checkout!(
                 store.id,
                 [%{variant_id: variant.id, quantity: 4}],
                 []
               )

      assert Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false).stock_quantity == 10
    end

    test "order total equals sum of line totals", %{store: store, product: product} do
      v1 = create_variant!(product, store, price: 12_000, stock_quantity: 10)
      v2 = create_variant!(product, store, price: 8_000, stock_quantity: 10)

      items = [
        %{variant_id: v1.id, quantity: 2},
        %{variant_id: v2.id, quantity: 3}
      ]

      assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

      # 12000*2 + 8000*3 = 24000 + 24000 = 48000
      assert order.total == 48_000
    end

    test "checkout with shipping and billing addresses", %{store: store, variant: variant} do
      address = %{"street" => "15 Osu Badu", "city" => "Accra"}
      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items,
                 shipping_address: address,
                 billing_address: address,
                 notes: "Ring the bell"
               )

      assert order.shipping_address == address
      assert order.billing_address == address
      assert order.notes == "Ring the bell"
    end
  end

  # -- Product availability re-validation -----------------------------

  describe "product availability re-validation" do
    test "rejects checkout of an archived product", %{store: store, customer: customer} do
      product = create_product!(store, title: "Discontinued", status: :archived)
      variant = create_variant!(product, store, price: 5_000, stock_quantity: 10)
      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:error, :product_unavailable} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items, customer_id: customer.id)
    end

    test "rejects checkout of a taken-down product", %{store: store, customer: customer} do
      product = create_product!(store, title: "Counterfeit", status: :active)
      variant = create_variant!(product, store, price: 5_000, stock_quantity: 10)
      {:ok, _} = Emakola.Catalog.take_down_product(product, %{reason: "x"}, authorize?: false)
      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:error, :product_unavailable} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items, customer_id: customer.id)
    end
  end

  # -- Error cases ----------------------------------------------------

  describe "error cases" do
    test "rejects empty cart", %{store: store} do
      assert {:error, :empty_cart} =
               Emakola.Orders.CheckoutService.checkout!(store.id, [], [])
    end

    test "rejects insufficient stock", %{store: store, variant: variant} do
      # variant has stock_quantity: 10
      items = [%{variant_id: variant.id, quantity: 11}]

      assert {:error, :insufficient_stock} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

      # Stock should be unchanged
      refreshed =
        Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false, authorize?: false)

      assert refreshed.stock_quantity == 10
    end

    test "rejects variant from different store", %{variant: variant} do
      other_store = create_store!()
      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:error, :variant_not_in_store} =
               Emakola.Orders.CheckoutService.checkout!(other_store.id, items, [])
    end

    test "rejects non-existent variant", %{store: store} do
      fake_id = Ash.UUID.generate()
      items = [%{variant_id: fake_id, quantity: 1}]

      assert {:error, :variant_not_found} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items, [])
    end
  end

  # -- Task 3 (supplier-stock-truth): live supplier stock validation --
  # The reseller listing variant's `available` flag is a boolean synced
  # asynchronously by SupplierStockSyncWorker — it can't express "customer
  # wants 5, supplier has 2". Checkout must consult the live source-variant
  # stock for network (dropship) items, not just the boolean flag.

  describe "network stock validation" do
    setup do
      {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Stock Wholesaler"})
      {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Stock Reseller"})

      {:ok, connection} =
        Network.request(wholesaler_actor, %{
          wholesaler_store_id: wholesaler.id,
          reseller_store_id: reseller.id,
          requested_by_store_id: wholesaler.id
        })

      {:ok, _active} = Network.approve(reseller_actor, connection)

      %{
        wholesaler_actor: wholesaler_actor,
        wholesaler: wholesaler,
        reseller_actor: reseller_actor,
        reseller: reseller
      }
    end

    test "supplier stock below the requested quantity blocks checkout even though the flag reads available",
         ctx do
      %{reseller_variant: reseller_variant} = import_network_variant!(ctx, 2)

      items = [%{variant_id: reseller_variant.id, quantity: 5}]

      assert {:error, :insufficient_stock} =
               Emakola.Orders.CheckoutService.checkout!(ctx.reseller.id, items, [])
    end

    test "supplier stock covering the requested quantity succeeds", ctx do
      %{reseller_variant: reseller_variant} = import_network_variant!(ctx, 2)

      items = [%{variant_id: reseller_variant.id, quantity: 2}]

      assert {:ok, _order} =
               Emakola.Orders.CheckoutService.checkout!(ctx.reseller.id, items, [])
    end

    test "stale flag: reseller variant reads available but the live source is out of stock",
         ctx do
      %{reseller_variant: reseller_variant, source_variant: source_variant} =
        import_network_variant!(ctx, 5)

      # Supplier stock drops to zero without the async sync worker having run
      # yet — the reseller variant's `available` flag is still true.
      source_variant
      |> Ash.Changeset.for_update(:adjust_stock, %{delta: -5})
      |> Ash.update!(authorize?: false)

      assert reload_variant(source_variant).stock_quantity == 0
      assert reload_variant(reseller_variant).available == true

      items = [%{variant_id: reseller_variant.id, quantity: 1}]

      assert {:error, :insufficient_stock} =
               Emakola.Orders.CheckoutService.checkout!(ctx.reseller.id, items, [])
    end

    test "unmapped supplier-linked variant (manual off-platform supplier) keeps flag-only behaviour",
         ctx do
      product = create_product!(ctx.reseller, status: :active, title: "Manual Dropship")
      supplier = create_supplier!(ctx.reseller)

      orphan_variant =
        create_variant!(product, ctx.reseller,
          supplier_id: supplier.id,
          available: true,
          track_inventory: false,
          stock_quantity: 0
        )

      items = [%{variant_id: orphan_variant.id, quantity: 5}]

      assert {:ok, _order} =
               Emakola.Orders.CheckoutService.checkout!(ctx.reseller.id, items, [])
    end
  end

  # Real network flow (Offers -> publish -> ListingImporter), mirroring
  # NetworkStockTest's fixture — a genuine ResellerListingVariant/offer chain
  # is required so `load_source_variants/1` has a mapping to batch-load.
  defp import_network_variant!(ctx, source_stock_quantity) do
    product = create_product!(ctx.wholesaler, status: :active, title: "Kente Sandals")

    source_variant =
      create_variant!(product, ctx.wholesaler,
        price: 6_000,
        sku: "SRC-#{System.unique_integer([:positive])}",
        stock_quantity: source_stock_quantity
      )

    {:ok, offer} =
      Offers.create_draft(ctx.wholesaler_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup
      })

    {:ok, _terms} =
      Offers.add_variant(ctx.wholesaler_actor, offer, %{
        source_variant_id: source_variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 5_800
      })

    {:ok, published} = Offers.publish(ctx.wholesaler_actor, offer)
    {:ok, listing} = ListingImporter.import(ctx.reseller_actor, ctx.reseller.id, published)

    [reseller_variant | _] = listing.reseller_product.variants

    %{source_variant: source_variant, reseller_variant: reseller_variant}
  end

  defp reload_variant(variant),
    do: Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)

  # -- C1 regression: stock error classification ----------------------
  # Before the C1 fix, ANY Ash.Error.Invalid caught in run_checkout/4 was
  # mapped to {:error, :insufficient_stock}. This tested the pure
  # classification helper so we can trust the pattern matching even
  # without reproducing every failure mode end-to-end.

  describe "stock_constraint_violation? classification" do
    alias Emakola.Orders.CheckoutService

    test "returns true for stock_non_negative constraint violation" do
      error =
        %Ash.Error.Invalid{
          errors: [
            %{constraint: "stock_non_negative", message: "check constraint violated"}
          ]
        }

      assert CheckoutService.stock_constraint_violation?(error) == true
    end

    test "returns true for :stock_quantity field error" do
      error =
        %Ash.Error.Invalid{
          errors: [%{field: :stock_quantity, message: "must be non-negative"}]
        }

      assert CheckoutService.stock_constraint_violation?(error) == true
    end

    test "returns true when error message mentions 'stock'" do
      error =
        %Ash.Error.Invalid{
          errors: [%{message: "insufficient stock for variant"}]
        }

      assert CheckoutService.stock_constraint_violation?(error) == true
    end

    test "returns false for unrelated validation errors" do
      error =
        %Ash.Error.Invalid{
          errors: [%{field: :shipping_address, message: "is invalid"}]
        }

      assert CheckoutService.stock_constraint_violation?(error) == false
    end

    test "returns false for non-Ash.Error.Invalid structs" do
      assert CheckoutService.stock_constraint_violation?(%RuntimeError{message: "boom"}) == false
      assert CheckoutService.stock_constraint_violation?(nil) == false
      assert CheckoutService.stock_constraint_violation?(:some_atom) == false
    end

    test "returns false for Ash.Error.Invalid with empty errors list" do
      assert CheckoutService.stock_constraint_violation?(%Ash.Error.Invalid{errors: []}) == false
    end
  end

  # -- Concurrency ----------------------------------------------------

  describe "concurrent checkouts" do
    test "both succeed — checkout reserves no stock (no-reservation model)", %{
      store: store,
      product: product
    } do
      # Create variant with exactly 5 units
      scarce_variant = create_variant!(product, store, price: 50_000, stock_quantity: 5)

      items = [%{variant_id: scarce_variant.id, quantity: 5}]

      tasks =
        for _i <- 1..2 do
          Task.async(fn ->
            Emakola.Orders.CheckoutService.checkout!(store.id, items, [])
          end)
        end

      results = Enum.map(tasks, &Task.await/1)

      # Stock is reserved nowhere at checkout, so both orders are placed; the
      # oversell is resolved at payment confirmation, not here.
      assert Enum.count(results, &match?({:ok, _}, &1)) == 2

      refreshed =
        Ash.get!(Emakola.Catalog.Variant, scarce_variant.id, authorize?: false, authorize?: false)

      assert refreshed.stock_quantity == 5
    end

    test "confirming more orders than stock clamps at zero, both stay confirmed (oversell)",
         %{store: store, product: product} do
      variant = create_variant!(product, store, price: 10_000, stock_quantity: 1)
      items = [%{variant_id: variant.id, quantity: 1}]

      {:ok, order1} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])
      {:ok, order2} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

      # Both paid orders confirm; the second decrement is logged as oversold and
      # the order still stands for manual fulfilment. Stock never goes negative.
      assert {:ok, c1} = Emakola.Orders.confirm_order(order1, authorize?: false)
      assert {:ok, c2} = Emakola.Orders.confirm_order(order2, authorize?: false)
      assert c1.status == :confirmed
      assert c2.status == :confirmed

      assert Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false).stock_quantity == 0
    end
  end

  # -- Customer find-or-create integration ------------------------------

  describe "customer_email checkout" do
    test "creates new customer when email not found", %{store: store, variant: variant} do
      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items,
                 customer_email: "new-checkout@example.com",
                 customer_name: "New Buyer",
                 customer_phone: "+233240001111"
               )

      assert order.customer_id

      customer =
        Ash.get!(Emakola.Customers.Customer, order.customer_id,
          authorize?: false,
          authorize?: false
        )

      assert to_string(customer.email) == "new-checkout@example.com"
      assert customer.name == "New Buyer"
    end

    test "links to existing customer when email matches", %{
      store: store,
      variant: variant,
      customer: customer
    } do
      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items,
                 customer_email: to_string(customer.email)
               )

      assert order.customer_id == customer.id
    end

    test "customer_id fallback still works (backward compat)", %{
      store: store,
      variant: variant,
      customer: customer
    } do
      items = [%{variant_id: variant.id, quantity: 1}]
      opts = [customer_id: customer.id]

      assert {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, opts)
      assert order.customer_id == customer.id
    end

    test "uses default address when no shipping_address provided", %{
      store: store,
      variant: variant,
      customer: customer
    } do
      addr =
        create_address!(customer, store,
          line_1: "42 Independence Ave",
          city: "Accra",
          region: "Greater Accra"
        )

      Emakola.Customers.Address
      |> Ash.ActionInput.for_action(:set_as_default, %{address_id: addr.id})
      |> Ash.run_action!()

      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items,
                 customer_email: to_string(customer.email)
               )

      assert order.shipping_address["line_1"] == "42 Independence Ave"
      assert order.shipping_address["city"] == "Accra"
    end

    test "explicit shipping_address overrides default address", %{
      store: store,
      variant: variant,
      customer: customer
    } do
      addr =
        create_address!(customer, store,
          line_1: "Default Street",
          city: "Accra"
        )

      Emakola.Customers.Address
      |> Ash.ActionInput.for_action(:set_as_default, %{address_id: addr.id})
      |> Ash.run_action!()

      explicit = %{"line_1" => "Explicit Street", "city" => "Kumasi"}
      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items,
                 customer_email: to_string(customer.email),
                 shipping_address: explicit
               )

      assert order.shipping_address["line_1"] == "Explicit Street"
    end

    test "updates last_order_at after checkout", %{store: store, variant: variant} do
      items = [%{variant_id: variant.id, quantity: 1}]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(store.id, items,
                 customer_email: "lastorder@example.com"
               )

      customer =
        Ash.get!(Emakola.Customers.Customer, order.customer_id,
          authorize?: false,
          authorize?: false
        )

      assert %DateTime{} = customer.last_order_at
    end
  end

  # -- Dispatch fee computation + snapshots -----------------------------
  # Fixtures import real supplier-backed variants via the network flow
  # (Offers -> publish -> ListingImporter) so a genuine
  # ResellerListingVariant/offer chain exists for dispatch_fees_for/3 to
  # read — a factory-only supplier_id (as used by the dropship describes in
  # checkout_ledger_test.exs) has no listing/offer to carry a dispatch fee.

  describe "dispatch fees" do
    setup do
      {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Dispatch Reseller"})
      verified_payout!(reseller)
      {:ok, reseller_actor: reseller_actor, reseller: reseller}
    end

    test "charges the max fee per supplier for the customer's region and snapshots it", %{
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop_a =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      drop_b =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 2_500
        })

      assert drop_a.supplier_id == drop_b.supplier_id

      items = [
        %{variant_id: drop_a.variant.id, quantity: 1},
        %{variant_id: drop_b.variant.id, quantity: 1}
      ]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items,
                 region: "greater_accra",
                 delivery_fee: 1_000
               )

      assert order.dispatch_fee_total == 2_500
      assert order.total == order.subtotal + 1_000 + 2_500 - 0

      assert [fulfillment] =
               Emakola.Orders.list_fulfillments_by_order!(order.id, authorize?: false)

      assert fulfillment.supplier_id == drop_a.supplier_id
      assert fulfillment.dispatch_fee == 2_500

      assert {:ok, [entry]} =
               Emakola.Suppliers.list_ledger_entries_by_supplier(drop_a.supplier_id,
                 authorize?: false
               )

      assert entry.amount_owed == 8_000 + 2_500
    end

    test "unquoted region and merchant-owned lines charge zero", %{
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop_a =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      drop_b =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 2_500
        })

      own_product = create_product!(reseller, title: "Merchant Own Product")
      own_variant = create_variant!(own_product, reseller, price: 3_000, stock_quantity: 10)

      items = [
        %{variant_id: drop_a.variant.id, quantity: 1},
        %{variant_id: drop_b.variant.id, quantity: 1},
        %{variant_id: own_variant.id, quantity: 1}
      ]

      assert {:ok, unquoted} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items, region: "volta")

      assert unquoted.dispatch_fee_total == 0

      assert {:ok, other_region} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items, region: "other")

      assert other_region.dispatch_fee_total == 0

      assert {:ok, no_region} = Emakola.Orders.CheckoutService.checkout!(reseller.id, items, [])
      assert no_region.dispatch_fee_total == 0
    end

    test "multi-supplier carts compose per supplier", %{
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      {wholesaler_a_actor, wholesaler_a} = create_dropship_wholesaler!(reseller_actor, reseller)
      {wholesaler_b_actor, wholesaler_b} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop_a =
        import_offer!(wholesaler_a_actor, wholesaler_a, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      drop_b =
        import_offer!(wholesaler_b_actor, wholesaler_b, reseller_actor, reseller, %{
          "Greater Accra" => 3_000
        })

      refute drop_a.supplier_id == drop_b.supplier_id

      items = [
        %{variant_id: drop_a.variant.id, quantity: 1},
        %{variant_id: drop_b.variant.id, quantity: 1}
      ]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items,
                 region: "greater_accra"
               )

      assert order.dispatch_fee_total == 4_500

      fulfillments = Emakola.Orders.list_fulfillments_by_order!(order.id, authorize?: false)
      fee_by_supplier = Map.new(fulfillments, fn f -> {f.supplier_id, f.dispatch_fee} end)

      assert fee_by_supplier[drop_a.supplier_id] == 1_500
      assert fee_by_supplier[drop_b.supplier_id] == 3_000
    end

    test "later offer edits do not change the snapshot", %{
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      items = [%{variant_id: drop.variant.id, quantity: 1}]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items,
                 region: "greater_accra"
               )

      assert order.dispatch_fee_total == 1_500

      {:ok, _updated} =
        Offers.update_terms(wholesaler_actor, drop.offer, %{
          dispatch_fees: %{"Greater Accra" => 9_900}
        })

      reloaded_order = Ash.get!(Emakola.Orders.Order, order.id, authorize?: false)
      assert reloaded_order.dispatch_fee_total == 1_500

      assert [fulfillment] =
               Emakola.Orders.list_fulfillments_by_order!(order.id, authorize?: false)

      assert fulfillment.dispatch_fee == 1_500
    end
  end

  # -- Dispatch fee fixtures ---------------------------------------------
  # Real network flow (Offers -> publish -> ListingImporter) so the
  # imported variant carries a genuine ResellerListingVariant/offer chain.

  defp create_dropship_wholesaler!(reseller_actor, reseller) do
    {wholesaler_actor, wholesaler} =
      create_merchant_with_store!(%{
        name: "Dispatch Wholesaler #{System.unique_integer([:positive])}"
      })

    {:ok, connection} =
      Network.request(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: wholesaler.id
      })

    {:ok, _active} = Network.approve(reseller_actor, connection)
    verified_payout!(wholesaler)

    {wholesaler_actor, wholesaler}
  end

  defp import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, dispatch_fees) do
    product =
      create_product!(wholesaler,
        status: :active,
        title: "Dispatch Item #{System.unique_integer([:positive])}"
      )

    source_variant =
      create_variant!(product, wholesaler,
        price: 6_000,
        sku: "SRC-#{System.unique_integer([:positive])}",
        stock_quantity: 50
      )

    {:ok, offer} =
      Offers.create_draft(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: Map.keys(dispatch_fees)
      })

    {:ok, _terms} =
      Offers.add_variant(wholesaler_actor, offer, %{
        source_variant_id: source_variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 5_800
      })

    {:ok, published} = Offers.publish(wholesaler_actor, offer)

    {:ok, priced} =
      Offers.update_terms(wholesaler_actor, published, %{dispatch_fees: dispatch_fees})

    {:ok, listing} = ListingImporter.import(reseller_actor, reseller.id, priced)

    [variant | _] = listing.reseller_product.variants
    %{variant: variant, supplier_id: listing.supplier_id, offer: priced}
  end

  defp verified_payout!(store) do
    account =
      Emakola.Stores.StorePayoutAccount
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        payout_provider: :paystack,
        payout_destination: %{"type" => "momo", "number" => "0244000000"}
      })
      |> Ash.create!(authorize?: false)

    account
    |> Ash.Changeset.for_update(:record_subaccount, %{
      subaccount_code: "ACCT_#{System.unique_integer([:positive])}"
    })
    |> Ash.update!(authorize?: false)
  end
end
