defmodule Emakola.Customers.WishlistItemTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory

  setup do
    store =
      Factory.create_store!(%{name: "Wishlist Store", slug: "wishlist-store", currency: "GHS"})

    customer = Factory.create_customer!(store)
    product = Factory.create_product!(store, %{title: "Kente Dress"})
    _variant = Factory.create_variant!(product, store, %{price: 28_000, stock_quantity: 5})

    %{store: store, customer: customer, product: product}
  end

  describe "add_to_wishlist/1" do
    test "adds a product to the customer wishlist", %{
      store: store,
      customer: customer,
      product: product
    } do
      assert {:ok, item} =
               Emakola.Customers.add_to_wishlist(%{
                 customer_id: customer.id,
                 product_id: product.id,
                 store_id: store.id
               })

      assert item.customer_id == customer.id
      assert item.product_id == product.id
      assert item.store_id == store.id
    end

    test "upserts on duplicate instead of raising", %{
      store: store,
      customer: customer,
      product: product
    } do
      {:ok, first} =
        Emakola.Customers.add_to_wishlist(%{
          customer_id: customer.id,
          product_id: product.id,
          store_id: store.id
        })

      {:ok, second} =
        Emakola.Customers.add_to_wishlist(%{
          customer_id: customer.id,
          product_id: product.id,
          store_id: store.id
        })

      # Upsert returns the same record
      assert first.id == second.id
    end

    test "allows same product for different customers", %{store: store, product: product} do
      customer_a = Factory.create_customer!(store, %{email: "a@example.com"})
      customer_b = Factory.create_customer!(store, %{email: "b@example.com"})

      assert {:ok, _} =
               Emakola.Customers.add_to_wishlist(%{
                 customer_id: customer_a.id,
                 product_id: product.id,
                 store_id: store.id
               })

      assert {:ok, _} =
               Emakola.Customers.add_to_wishlist(%{
                 customer_id: customer_b.id,
                 product_id: product.id,
                 store_id: store.id
               })
    end

    # WishlistLive.toggle_wishlist writes store_id from the acting storefront
    # without checking the client-supplied product_id belongs to it — this is
    # the write-time gate that closes that gap (the wishlist_count aggregate's
    # parent(store_id) filter is defence in depth on the read side).
    test "refuses a product that belongs to another store", %{
      store: store,
      customer: customer
    } do
      other_store =
        Factory.create_store!(%{name: "Other Store", slug: "other-store", currency: "GHS"})

      foreign_product = Factory.create_product!(other_store, %{title: "Foreign Product"})

      assert {:error, error} =
               Emakola.Customers.add_to_wishlist(%{
                 customer_id: customer.id,
                 product_id: foreign_product.id,
                 store_id: store.id
               })

      assert Exception.message(error) =~ "not in this shop"
    end
  end

  describe "remove_from_wishlist/1" do
    test "removes an existing wishlist item", %{
      store: store,
      customer: customer,
      product: product
    } do
      {:ok, _item} =
        Emakola.Customers.add_to_wishlist(%{
          customer_id: customer.id,
          product_id: product.id,
          store_id: store.id
        })

      assert {:ok, _removed} =
               Emakola.Customers.remove_from_wishlist(customer.id, product.id, store.id,
                 authorize?: false
               )

      # Verify it is gone
      {:ok, items} = Emakola.Customers.list_wishlist(customer.id, store.id, authorize?: false)
      assert items == []
    end

    test "returns nil when item does not exist", %{
      store: store,
      customer: customer,
      product: product
    } do
      assert {:ok, nil} =
               Emakola.Customers.remove_from_wishlist(customer.id, product.id, store.id,
                 authorize?: false
               )
    end
  end

  describe "list_wishlist/2" do
    test "returns empty list when no items saved", %{store: store, customer: customer} do
      assert {:ok, []} = Emakola.Customers.list_wishlist(customer.id, store.id, authorize?: false)
    end

    test "returns items ordered by most recently added", %{store: store, customer: customer} do
      product_a = Factory.create_product!(store, %{title: "Product A"})
      Factory.create_variant!(product_a, store, %{price: 10_000, stock_quantity: 3})

      product_b = Factory.create_product!(store, %{title: "Product B"})
      Factory.create_variant!(product_b, store, %{price: 20_000, stock_quantity: 7})

      Emakola.Customers.add_to_wishlist(%{
        customer_id: customer.id,
        product_id: product_a.id,
        store_id: store.id
      })

      # Ensure different inserted_at timestamp (usec precision needs enough gap)
      Process.sleep(50)

      Emakola.Customers.add_to_wishlist(%{
        customer_id: customer.id,
        product_id: product_b.id,
        store_id: store.id
      })

      {:ok, items} = Emakola.Customers.list_wishlist(customer.id, store.id, authorize?: false)
      assert length(items) == 2
      # Most recent first — verify ordering works in general
      [first, second] = items
      assert first.inserted_at >= second.inserted_at
    end

    test "loads product associations", %{store: store, customer: customer, product: product} do
      Factory.create_variant!(product, store, %{price: 15_000, stock_quantity: 2})

      Emakola.Customers.add_to_wishlist(%{
        customer_id: customer.id,
        product_id: product.id,
        store_id: store.id
      })

      {:ok, [item]} = Emakola.Customers.list_wishlist(customer.id, store.id, authorize?: false)
      assert item.product.title == "Kente Dress"
    end

    test "does not return items from other stores", %{customer: _customer, product: _product} do
      store_a = Factory.create_store!(%{name: "Store A", slug: "store-a", currency: "GHS"})
      store_b = Factory.create_store!(%{name: "Store B", slug: "store-b", currency: "GHS"})
      customer_a = Factory.create_customer!(store_a)
      product_a = Factory.create_product!(store_a, %{title: "Store A Product"})
      Factory.create_variant!(product_a, store_a, %{price: 5_000, stock_quantity: 1})

      Emakola.Customers.add_to_wishlist(%{
        customer_id: customer_a.id,
        product_id: product_a.id,
        store_id: store_a.id
      })

      {:ok, items} = Emakola.Customers.list_wishlist(customer_a.id, store_b.id)
      assert items == []
    end
  end
end
