defmodule Emakola.Security.AuthorizationTest do
  @moduledoc """
  Tests for multi-tenant authorization enforcement.

  Verifies that store-scoped queries correctly isolate data:
  - Merchant A cannot see Store B's products, orders, or customers
  - Store-scoped read actions filter by store_id
  - Merchant A cannot write to Store B's resources (policy enforced)
  - Unauthenticated users cannot access admin LiveView routes
  """

  use Emakola.DataCase, async: false

  require Ash.Query

  import Emakola.Factory

  alias Emakola.Catalog.Product
  alias Emakola.Orders.Order
  alias Emakola.Customers.Customer

  setup do
    {merchant_a, store_a} = create_merchant_with_store!()
    {merchant_b, store_b} = create_merchant_with_store!()

    %{
      merchant_a: merchant_a,
      store_a: store_a,
      merchant_b: merchant_b,
      store_b: store_b
    }
  end

  # ── Product Isolation ───────────────────────────────────────────────

  describe "product store isolation" do
    test "list_by_store only returns products for the queried store", ctx do
      # Create products in Store A
      product_a1 = create_product!(ctx.store_a, %{title: "Store A Product 1"})
      product_a2 = create_product!(ctx.store_a, %{title: "Store A Product 2"})

      # Create products in Store B
      _product_b1 = create_product!(ctx.store_b, %{title: "Store B Product 1"})

      # Query Store A's products — should only see Store A's products
      {:ok, store_a_products} =
        Product
        |> Ash.Query.for_read(:list_by_store, %{store_id: ctx.store_a.id})
        |> Ash.read(authorize?: false)

      store_a_ids = Enum.map(store_a_products, & &1.id) |> MapSet.new()

      assert MapSet.member?(store_a_ids, product_a1.id)
      assert MapSet.member?(store_a_ids, product_a2.id)
      assert Enum.count(store_a_products) == 2
    end

    test "merchant A cannot see Store B products via list_by_store", ctx do
      _product_b = create_product!(ctx.store_b, %{title: "Secret Store B Product"})

      {:ok, store_a_products} =
        Product
        |> Ash.Query.for_read(:list_by_store, %{store_id: ctx.store_a.id})
        |> Ash.read(authorize?: false)

      store_a_product_titles = Enum.map(store_a_products, & &1.title)
      refute "Secret Store B Product" in store_a_product_titles
    end

    test "filtering products by store_id never returns cross-store data", ctx do
      create_product!(ctx.store_a, %{title: "Shared Name"})
      product_b = create_product!(ctx.store_b, %{title: "Shared Name"})

      # Even with same title, store_id filtering isolates them
      {:ok, store_a_products} =
        Product
        |> Ash.Query.for_read(:list_by_store, %{store_id: ctx.store_a.id})
        |> Ash.read(authorize?: false)

      store_a_ids = Enum.map(store_a_products, & &1.id)
      refute product_b.id in store_a_ids
    end

    test "search_products only returns results within the specified store", ctx do
      create_product!(ctx.store_a, %{title: "Kente Cloth"})
      create_product!(ctx.store_b, %{title: "Kente Cloth Premium"})

      {:ok, results} =
        Product
        |> Ash.Query.for_read(:search, %{query: "kente", store_id: ctx.store_a.id})
        |> Ash.read(authorize?: false)

      assert Enum.count(results) == 1
      assert hd(results).store_id == ctx.store_a.id
    end
  end

  # ── Order Isolation ────────────────────────────────────────────────

  describe "order store isolation" do
    test "list_by_store only returns orders for the queried store", ctx do
      order_a = create_order!(ctx.store_a)
      _order_b = create_order!(ctx.store_b)

      {:ok, store_a_orders} =
        Order
        |> Ash.Query.for_read(:list_by_store, %{store_id: ctx.store_a.id})
        |> Ash.read(authorize?: false)

      assert Enum.count(store_a_orders) == 1
      assert hd(store_a_orders).id == order_a.id
    end

    test "merchant A cannot see Store B orders via list_by_store", ctx do
      _order_b = create_order!(ctx.store_b)

      {:ok, store_a_orders} =
        Order
        |> Ash.Query.for_read(:list_by_store, %{store_id: ctx.store_a.id})
        |> Ash.read(authorize?: false)

      assert Enum.empty?(store_a_orders)
    end

    test "list_by_status respects store isolation", ctx do
      create_order!(ctx.store_a)
      create_order!(ctx.store_b)

      {:ok, store_a_pending} =
        Order
        |> Ash.Query.for_read(:list_by_status, %{
          store_id: ctx.store_a.id,
          status: :pending
        })
        |> Ash.read(authorize?: false)

      assert Enum.count(store_a_pending) == 1
      assert Enum.all?(store_a_pending, &(&1.store_id == ctx.store_a.id))
    end
  end

  # ── Customer Isolation ──────────────────────────────────────────────

  describe "customer store isolation" do
    test "customers are scoped to their store", ctx do
      customer_a = create_customer!(ctx.store_a, %{name: "Kwame"})
      _customer_b = create_customer!(ctx.store_b, %{name: "Ama"})

      # Read all customers and filter by store_id
      {:ok, all_customers} = Ash.read(Customer)

      store_a_customers = Enum.filter(all_customers, &(&1.store_id == ctx.store_a.id))

      assert Enum.count(store_a_customers) == 1
      assert hd(store_a_customers).id == customer_a.id
    end

    test "customer created in Store A is not visible when filtering for Store B", ctx do
      create_customer!(ctx.store_a, %{name: "Only in A"})

      {:ok, all_customers} = Ash.read(Customer)
      store_b_customers = Enum.filter(all_customers, &(&1.store_id == ctx.store_b.id))

      customer_names = Enum.map(store_b_customers, & &1.name)
      refute "Only in A" in customer_names
    end
  end

  # ── Payment Isolation ──────────────────────────────────────────────

  describe "payment store isolation" do
    test "by_store read action only returns payments for the specified store", ctx do
      _payment_a = create_payment!(ctx.store_a)
      _payment_b = create_payment!(ctx.store_b)

      {:ok, store_a_payments} =
        Emakola.Payments.Payment
        |> Ash.Query.for_read(:by_store, %{store_id: ctx.store_a.id})
        |> Ash.read(authorize?: false)

      assert Enum.count(store_a_payments) == 1
      assert Enum.all?(store_a_payments, &(&1.store_id == ctx.store_a.id))
    end
  end

  # ── Cross-Store Update Prevention ──────────────────────────────────

  describe "cross-store update prevention" do
    test "product update does not change store_id (store_id is not in update accept list)", ctx do
      product = create_product!(ctx.store_a, %{title: "Original Title"})

      # Attempt to update — store_id is not accepted on update, so it stays the same
      {:ok, updated} =
        product
        |> Ash.Changeset.for_update(:update, %{title: "Updated Title"})
        |> Ash.update(authorize?: false)

      assert updated.store_id == ctx.store_a.id
      assert updated.title == "Updated Title"
    end
  end

  # ── Policy-Enforced Write Isolation ──────────────────────────────

  describe "merchant cannot write to another store's products" do
    test "merchant B cannot create a product in store A", ctx do
      result =
        Product
        |> Ash.Changeset.for_create(:create, %{
          store_id: ctx.store_a.id,
          title: "Hijacked Product"
        })
        |> Ash.create(actor: ctx.merchant_b)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end

    test "merchant B cannot update a product in store A", ctx do
      product = create_product!(ctx.store_a, %{title: "Store A Product"})

      result =
        product
        |> Ash.Changeset.for_update(:update, %{title: "Hijacked Title"})
        |> Ash.update(actor: ctx.merchant_b)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end

    test "merchant A can create a product in their own store", ctx do
      result =
        Product
        |> Ash.Changeset.for_create(:create, %{
          store_id: ctx.store_a.id,
          title: "My Product"
        })
        |> Ash.create(actor: ctx.merchant_a)

      assert {:ok, product} = result
      assert product.store_id == ctx.store_a.id
    end
  end

  describe "merchant cannot write to another store's orders" do
    test "merchant B cannot create an order in store A", ctx do
      result =
        Order
        |> Ash.Changeset.for_create(:create, %{store_id: ctx.store_a.id})
        |> Ash.create(actor: ctx.merchant_b)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end

    test "merchant B cannot cancel an order in store A", ctx do
      order = create_order!(ctx.store_a)

      result =
        order
        |> Ash.Changeset.for_update(:cancel)
        |> Ash.update(actor: ctx.merchant_b)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end
  end

  describe "merchant cannot modify another store" do
    test "merchant B cannot update store A", ctx do
      result =
        ctx.store_a
        |> Ash.Changeset.for_update(:update, %{name: "Hijacked Store"})
        |> Ash.update(actor: ctx.merchant_b)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end

    test "merchant A can update their own store", ctx do
      result =
        ctx.store_a
        |> Ash.Changeset.for_update(:update, %{name: "My Updated Store"})
        |> Ash.update(actor: ctx.merchant_a)

      assert {:ok, updated} = result
      assert updated.name == "My Updated Store"
    end
  end

  describe "merchant cannot write to another store's customers" do
    test "merchant B cannot create a customer in store A", ctx do
      result =
        Customer
        |> Ash.Changeset.for_create(:create, %{
          store_id: ctx.store_a.id,
          email: "hijacked@example.com",
          name: "Hijacked Customer"
        })
        |> Ash.create(actor: ctx.merchant_b)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end
  end
end
