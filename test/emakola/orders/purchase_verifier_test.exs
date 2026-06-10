defmodule Emakola.Orders.PurchaseVerifierTest do
  @moduledoc """
  Tests for Emakola.Orders.PurchaseVerifier.has_delivered_order?/3.

  Verifies that the function returns {:ok, order_id} when the customer has a
  delivered order containing the product, and {:error, :not_eligible} otherwise.
  """

  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Orders.PurchaseVerifier

  setup do
    {_merchant, store} = create_merchant_with_store!()
    product = create_product!(store, status: :active)
    variant = create_variant!(product, store, price: 5000)
    customer = create_customer!(store)

    {:ok, store: store, product: product, variant: variant, customer: customer}
  end

  defp create_delivered_order_with_item(store, customer, variant) do
    order =
      create_order!(store, %{
        customer_id: customer.id,
        total: 5000,
        subtotal: 5000,
        status: :delivered
      })

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    order
  end

  describe "has_delivered_order?/3" do
    test "returns {:ok, order_id} when customer has a delivered order with the product", ctx do
      order = create_delivered_order_with_item(ctx.store, ctx.customer, ctx.variant)

      assert {:ok, order_id} =
               PurchaseVerifier.has_delivered_order?(
                 ctx.store.id,
                 ctx.product.id,
                 ctx.customer.id
               )

      assert order_id == order.id
    end

    test "returns {:error, :not_eligible} when customer has no orders", ctx do
      assert {:error, :not_eligible} =
               PurchaseVerifier.has_delivered_order?(
                 ctx.store.id,
                 ctx.product.id,
                 ctx.customer.id
               )
    end

    test "returns {:error, :not_eligible} when order is not delivered", ctx do
      order =
        create_order!(ctx.store, %{
          customer_id: ctx.customer.id,
          total: 5000,
          subtotal: 5000
        })

      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: ctx.store.id,
        variant_id: ctx.variant.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

      assert {:error, :not_eligible} =
               PurchaseVerifier.has_delivered_order?(
                 ctx.store.id,
                 ctx.product.id,
                 ctx.customer.id
               )
    end

    test "returns {:error, :not_eligible} when the product is from a different product", ctx do
      other_product = create_product!(ctx.store, status: :active)
      _order = create_delivered_order_with_item(ctx.store, ctx.customer, ctx.variant)

      assert {:error, :not_eligible} =
               PurchaseVerifier.has_delivered_order?(
                 ctx.store.id,
                 other_product.id,
                 ctx.customer.id
               )
    end

    test "returns {:error, :not_eligible} when the customer belongs to a different store", ctx do
      {_other_merchant, other_store} = create_merchant_with_store!()
      other_customer = create_customer!(other_store)

      _order = create_delivered_order_with_item(ctx.store, ctx.customer, ctx.variant)

      assert {:error, :not_eligible} =
               PurchaseVerifier.has_delivered_order?(
                 ctx.store.id,
                 ctx.product.id,
                 other_customer.id
               )
    end

    test "scopes check to the given store_id (cross-tenant isolation)", ctx do
      {_other_merchant, other_store} = create_merchant_with_store!()
      other_product = create_product!(other_store, status: :active)
      other_variant = create_variant!(other_product, other_store)
      other_customer = create_customer!(other_store)

      _order = create_delivered_order_with_item(other_store, other_customer, other_variant)

      # Asking about ctx.store should not find the other store's order
      assert {:error, :not_eligible} =
               PurchaseVerifier.has_delivered_order?(
                 ctx.store.id,
                 other_product.id,
                 other_customer.id
               )
    end
  end
end
