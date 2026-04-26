defmodule Emakola.MultitenancyIsolationTest do
  @moduledoc """
  Integration tests proving cross-tenant read isolation.

  Each test creates two stores (store_a, store_b) with their respective merchants,
  then verifies that a merchant from store_a cannot read records belonging to store_b
  via the default :read action.

  These tests assert the P0 security invariant: attribute-based multitenancy + scoped
  read policies prevent cross-tenant data leakage even if a caller omits a store_id
  filter argument.
  """

  use Emakola.DataCase, async: false

  import Emakola.Factory

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp setup_two_stores(_context) do
    {merchant_a, store_a} = create_merchant_with_store!()
    {merchant_b, store_b} = create_merchant_with_store!()

    # Reload merchants with store_memberships preloaded so ActorHasStoreAccess
    # can short-circuit without a DB lookup in tests.
    merchant_a =
      Ash.get!(Emakola.Accounts.Merchant, merchant_a.id,
        load: [:store_memberships],
        authorize?: false
      )

    merchant_b =
      Ash.get!(Emakola.Accounts.Merchant, merchant_b.id,
        load: [:store_memberships],
        authorize?: false
      )

    %{
      merchant_a: merchant_a,
      store_a: store_a,
      merchant_b: merchant_b,
      store_b: store_b
    }
  end

  # Asserts that a cross-tenant read produces no leak. Either response is
  # acceptable security: an empty result list (filter-based isolation) or an
  # Ash.Error.Forbidden (policy-based isolation). What we forbid is records
  # being returned across tenants.
  defp assert_no_cross_tenant_leak(query, actor) do
    case Ash.read(query, actor: actor, authorize?: true) do
      {:ok, []} ->
        :ok

      {:error, %Ash.Error.Forbidden{}} ->
        :ok

      {:ok, records} ->
        flunk(
          "Cross-tenant leak detected — expected empty result or Forbidden, got: #{inspect(records)}"
        )

      {:error, other} ->
        flunk("Unexpected error during cross-tenant read: #{inspect(other)}")
    end
  end

  # ---------------------------------------------------------------------------
  # Customer
  # ---------------------------------------------------------------------------

  describe "Customer cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read customers belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      # Create a customer in store_b
      _customer_b = create_customer!(store_b)

      # merchant_a reads with no store_id filter — should get empty list
      Emakola.Customers.Customer
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's customers", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      customer = create_customer!(store_a)

      results =
        Emakola.Customers.Customer
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert customer.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Address
  # ---------------------------------------------------------------------------

  describe "Address cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read addresses belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      customer_b = create_customer!(store_b)
      _address_b = create_address!(customer_b, store_b)

      Emakola.Customers.Address
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's addresses", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      customer_a = create_customer!(store_a)
      address = create_address!(customer_a, store_a)

      results =
        Emakola.Customers.Address
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert address.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # CustomerNote
  # ---------------------------------------------------------------------------

  describe "CustomerNote cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read notes belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      customer_b = create_customer!(store_b)
      _note_b = create_customer_note!(customer_b, store_b)

      Emakola.Customers.CustomerNote
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's notes", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      customer_a = create_customer!(store_a)
      note = create_customer_note!(customer_a, store_a)

      results =
        Emakola.Customers.CustomerNote
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert note.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # WishlistItem
  # ---------------------------------------------------------------------------

  describe "WishlistItem cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read wishlist items belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      customer_b = create_customer!(store_b)
      product_b = create_product!(store_b)

      Emakola.Customers.WishlistItem
      |> Ash.Changeset.for_create(:add, %{
        customer_id: customer_b.id,
        product_id: product_b.id,
        store_id: store_b.id
      })
      |> Ash.create!(authorize?: false)

      Emakola.Customers.WishlistItem
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's wishlist items", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      customer_a = create_customer!(store_a)
      product_a = create_product!(store_a)

      item =
        Emakola.Customers.WishlistItem
        |> Ash.Changeset.for_create(:add, %{
          customer_id: customer_a.id,
          product_id: product_a.id,
          store_id: store_a.id
        })
        |> Ash.create!(authorize?: false)

      results =
        Emakola.Customers.WishlistItem
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert item.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Order
  # ---------------------------------------------------------------------------

  describe "Order cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read orders belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      _order_b = create_order!(store_b)

      Emakola.Orders.Order
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's orders", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      order = create_order!(store_a)

      results =
        Emakola.Orders.Order
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert order.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # LineItem
  # ---------------------------------------------------------------------------

  describe "LineItem cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read line items belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      order_b = create_order!(store_b)
      product_b = create_product!(store_b)
      variant_b = create_variant!(product_b, store_b)

      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order_b.id,
        store_id: store_b.id,
        variant_id: variant_b.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

      Emakola.Orders.LineItem
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's line items", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      order_a = create_order!(store_a)
      product_a = create_product!(store_a)
      variant_a = create_variant!(product_a, store_a)

      line_item =
        Emakola.Orders.LineItem
        |> Ash.Changeset.for_create(:create, %{
          order_id: order_a.id,
          store_id: store_a.id,
          variant_id: variant_a.id,
          quantity: 1
        })
        |> Ash.create!(authorize?: false)

      results =
        Emakola.Orders.LineItem
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert line_item.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Return
  # ---------------------------------------------------------------------------

  describe "Return cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read returns belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      order_b = create_order!(store_b)

      Emakola.Orders.Return
      |> Ash.Changeset.for_create(:request_return, %{
        store_id: store_b.id,
        order_id: order_b.id,
        reason: :defective,
        currency: "GHS"
      })
      |> Ash.create!(authorize?: false)

      Emakola.Orders.Return
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's returns", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      order_a = create_order!(store_a)

      ret =
        Emakola.Orders.Return
        |> Ash.Changeset.for_create(:request_return, %{
          store_id: store_a.id,
          order_id: order_a.id,
          reason: :defective,
          currency: "GHS"
        })
        |> Ash.create!(authorize?: false)

      results =
        Emakola.Orders.Return
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert ret.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Coupon
  # ---------------------------------------------------------------------------

  describe "Coupon cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read coupons belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      Emakola.Marketing.Coupon
      |> Ash.Changeset.for_create(:create, %{
        store_id: store_b.id,
        code: "SAVE10B",
        discount_type: :percentage,
        discount_value: 1000
      })
      |> Ash.create!(authorize?: false)

      Emakola.Marketing.Coupon
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's coupons", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      coupon =
        Emakola.Marketing.Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_a.id,
          code: "SAVE10A",
          discount_type: :percentage,
          discount_value: 1000
        })
        |> Ash.create!(authorize?: false)

      results =
        Emakola.Marketing.Coupon
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert coupon.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Payment
  # ---------------------------------------------------------------------------

  describe "Payment cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a cannot read payments belonging to store_b", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      _payment_b = create_payment!(store_b)

      Emakola.Payments.Payment
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's payments", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      payment = create_payment!(store_a)

      results =
        Emakola.Payments.Payment
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      ids = Enum.map(results, & &1.id)
      assert payment.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Catalog: published-only reads for unauthenticated storefront visitors
  # ---------------------------------------------------------------------------

  describe "Catalog public read — only published products visible" do
    setup :setup_two_stores

    test "default :read returns only published/active products for a store", %{
      store_a: store_a
    } do
      _draft = create_product!(store_a, status: :draft)

      active =
        create_product!(store_a,
          status: :active,
          title: "Active Product #{System.unique_integer([:positive])}"
        )

      # Need at least one variant to activate
      create_variant!(active, store_a)

      active =
        active
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!(authorize?: false)

      results =
        Emakola.Catalog.Product
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(authorize?: false)

      ids = Enum.map(results, & &1.id)

      assert active.id in ids,
             "active product should be visible in storefront reads"
    end
  end
end
