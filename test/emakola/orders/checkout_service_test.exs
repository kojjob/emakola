defmodule Emakola.Orders.CheckoutServiceTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

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
        |> Ash.load!(:line_items)
        |> Map.get(:line_items)

      assert length(line_items) == 2
    end

    test "stock is decremented after checkout", %{store: store, variant: variant} do
      items = [%{variant_id: variant.id, quantity: 3}]

      assert {:ok, _order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])

      updated_variant =
        Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false, authorize?: false)

      assert updated_variant.stock_quantity == 7
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
    test "competing for limited stock — one succeeds, one fails", %{
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

      successes = Enum.filter(results, &match?({:ok, _}, &1))
      failures = Enum.filter(results, &match?({:error, _}, &1))

      assert length(successes) == 1
      assert length(failures) == 1

      # Stock should be 0
      refreshed =
        Ash.get!(Emakola.Catalog.Variant, scarce_variant.id, authorize?: false, authorize?: false)

      assert refreshed.stock_quantity == 0
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
end
