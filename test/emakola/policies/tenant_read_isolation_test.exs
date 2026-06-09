defmodule Emakola.Policies.TenantReadIsolationTest do
  @moduledoc """
  Security regression tests for Findings 1 and 2 from the 2026-06-09 security audit.

  Finding 1: Blanket `bypass action_type(:read) do authorize_if(always()) end` on
  23+ ecommerce resources grants any actor (including unauthenticated) unconditional
  read access. These tests verify that a Merchant from store_A is denied when
  attempting to read store_B's data, and that system code via `authorize?: false`
  remains unaffected.

  Finding 2: Customer actor policies using `authorize_if(action_type(:read))` grant
  any authenticated Customer read access to ALL rows across ALL stores and customers.
  These tests verify row-level scoping: a Customer can only read records belonging to
  themselves, within their own store.
  """

  use Emakola.DataCase, async: false

  import Emakola.Factory

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  defp setup_two_stores(_context) do
    {merchant_a, store_a} = create_merchant_with_store!()
    {merchant_b, store_b} = create_merchant_with_store!()

    # Reload merchants with store_memberships preloaded so ActorHasStoreAccess
    # can short-circuit without an extra DB lookup.
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

    %{merchant_a: merchant_a, store_a: store_a, merchant_b: merchant_b, store_b: store_b}
  end

  # Either an empty result (filter-based isolation) or Forbidden (policy-based
  # isolation) is acceptable. What is NOT acceptable is records being returned
  # across tenant/owner boundaries.
  defp assert_no_cross_tenant_leak(query, actor) do
    case Ash.read(query, actor: actor, authorize?: true) do
      {:ok, []} ->
        :ok

      {:error, %Ash.Error.Forbidden{}} ->
        :ok

      {:ok, records} ->
        flunk(
          "Cross-tenant leak — expected empty result or Forbidden, got #{length(records)} record(s): #{inspect(Enum.map(records, & &1.id))}"
        )

      {:error, other} ->
        flunk("Unexpected error: #{inspect(other)}")
    end
  end

  # =========================================================================
  # FINDING 1 — Blanket read bypass on ecommerce resources
  # =========================================================================

  # ---------------------------------------------------------------------------
  # Supplier (high sensitivity: competitor MoMo numbers, payment details)
  # ---------------------------------------------------------------------------

  describe "Finding 1 — Supplier cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a is denied when reading with store_b's tenant", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      create_supplier!(store_b)

      Emakola.Suppliers.Supplier
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's suppliers", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      supplier_a = create_supplier!(store_a)

      results =
        Emakola.Suppliers.Supplier
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      assert supplier_a.id in Enum.map(results, & &1.id)
    end

    test "system code with authorize?: false bypasses policy and reads all (regression guard)", %{
      store_a: store_a,
      store_b: store_b
    } do
      create_supplier!(store_a)
      create_supplier!(store_b)

      # authorize?: false must still work — web layer and pipelines rely on this
      {:ok, results} = Ash.read(Emakola.Suppliers.Supplier, authorize?: false)
      assert length(results) >= 2
    end
  end

  # ---------------------------------------------------------------------------
  # SupplierLedgerEntry (financial: outstanding balances, amounts owed)
  # ---------------------------------------------------------------------------

  describe "Finding 1 — SupplierLedgerEntry cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a is denied when reading store_b ledger entries", %{
      merchant_a: merchant_a,
      store_b: store_b,
      store_a: store_a
    } do
      supplier_b = create_supplier!(store_b)
      order_b = create_order!(store_b)
      fulfillment_b = create_fulfillment!(order_b, store_b)
      create_supplier_ledger_entry!(supplier_b, fulfillment_b, store_b)

      # merchant_a reading with store_b's tenant must be denied
      # store_a merchant has no business reading store_b's ledger
      _ = store_a

      Emakola.Suppliers.SupplierLedgerEntry
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end
  end

  # ---------------------------------------------------------------------------
  # DownloadGrant (IDOR risk: arbitrary file access via grant UUID)
  # ---------------------------------------------------------------------------

  describe "Finding 1 — DownloadGrant cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a is denied when reading store_b's download grants", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      # Create a grant in store_b
      product_b = create_product!(store_b)
      variant_b = create_variant!(product_b, store_b)
      order_b = create_order!(store_b)

      line_item_b =
        Emakola.Orders.LineItem
        |> Ash.Changeset.for_create(:create, %{
          order_id: order_b.id,
          store_id: store_b.id,
          variant_id: variant_b.id,
          quantity: 1
        })
        |> Ash.create!(authorize?: false)

      digital_file_b =
        Emakola.Catalog.DigitalFile
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_b.id,
          product_id: product_b.id,
          file_name: "file.pdf",
          content_type: "application/pdf",
          storage_key: "stores/#{store_b.id}/file-#{System.unique_integer()}.pdf",
          byte_size: 1024
        })
        |> Ash.create!(authorize?: false)

      Emakola.Fulfillment.DownloadGrant
      |> Ash.Changeset.for_create(:issue, %{
        store_id: store_b.id,
        order_id: order_b.id,
        line_item_id: line_item_b.id,
        digital_file_id: digital_file_b.id
      })
      |> Ash.create!(authorize?: false)

      Emakola.Fulfillment.DownloadGrant
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end
  end

  # ---------------------------------------------------------------------------
  # Product (catalog isolation)
  # ---------------------------------------------------------------------------

  describe "Finding 1 — Product cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a is denied when reading store_b's products", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      create_product!(store_b)

      Emakola.Catalog.Product
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's products", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      product_a = create_product!(store_a)

      results =
        Emakola.Catalog.Product
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      assert product_a.id in Enum.map(results, & &1.id)
    end
  end

  # ---------------------------------------------------------------------------
  # DeliveryZone (shipping config — not financial but still tenant data)
  # ---------------------------------------------------------------------------

  describe "Finding 1 — DeliveryZone cross-tenant isolation" do
    setup :setup_two_stores

    test "merchant_a is denied when reading store_b's delivery zones", %{
      merchant_a: merchant_a,
      store_b: store_b
    } do
      create_delivery_zone!(store_b)

      Emakola.Shipping.DeliveryZone
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(merchant_a)
    end

    test "merchant_a can read their own store's delivery zones", %{
      merchant_a: merchant_a,
      store_a: store_a
    } do
      zone_a = create_delivery_zone!(store_a)

      results =
        Emakola.Shipping.DeliveryZone
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: merchant_a, authorize?: true)

      assert zone_a.id in Enum.map(results, & &1.id)
    end
  end

  # =========================================================================
  # FINDING 2 — Unscoped Customer actor read grants
  # =========================================================================

  # ---------------------------------------------------------------------------
  # Setup for Customer actor tests
  # ---------------------------------------------------------------------------

  defp setup_two_customers(_context) do
    {_, store_a} = create_merchant_with_store!()
    {_, store_b} = create_merchant_with_store!()

    customer_a = create_customer!(store_a)
    customer_b = create_customer!(store_a)
    customer_b_store_b = create_customer!(store_b)

    %{
      store_a: store_a,
      store_b: store_b,
      customer_a: customer_a,
      customer_b: customer_b,
      customer_b_store_b: customer_b_store_b
    }
  end

  # ---------------------------------------------------------------------------
  # Order row-scoping
  # ---------------------------------------------------------------------------

  describe "Finding 2 — Order actor row-scoping for Customer" do
    setup :setup_two_customers

    test "customer_a cannot read customer_b's orders", %{
      customer_a: customer_a,
      customer_b: customer_b,
      store_a: store_a
    } do
      # Create an order for customer_b (not customer_a)
      order_b = create_order!(store_a, customer_id: customer_b.id)

      results =
        Emakola.Orders.Order
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: customer_a, authorize?: true)

      result_ids = Enum.map(results, & &1.id)

      refute order_b.id in result_ids,
             "customer_a should not see customer_b's order"
    end

    test "customer_a can read their own orders", %{
      customer_a: customer_a,
      store_a: store_a
    } do
      order_a = create_order!(store_a, customer_id: customer_a.id)

      results =
        Emakola.Orders.Order
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: customer_a, authorize?: true)

      assert order_a.id in Enum.map(results, & &1.id),
             "customer_a should be able to read their own order"
    end

    test "customer from store_a cannot read store_b's orders", %{
      customer_a: customer_a,
      customer_b_store_b: customer_b_store_b,
      store_b: store_b
    } do
      _order_b = create_order!(store_b, customer_id: customer_b_store_b.id)

      # customer_a (store_a) attempting to read store_b data
      Emakola.Orders.Order
      |> Ash.Query.set_tenant(store_b.id)
      |> assert_no_cross_tenant_leak(customer_a)
    end
  end

  # ---------------------------------------------------------------------------
  # Address row-scoping (PII: customer shipping addresses)
  # ---------------------------------------------------------------------------

  describe "Finding 2 — Address row-scoping for Customer" do
    setup :setup_two_customers

    test "customer_a cannot read customer_b's addresses", %{
      customer_a: customer_a,
      customer_b: customer_b,
      store_a: store_a
    } do
      address_b = create_address!(customer_b, store_a)

      results =
        Emakola.Customers.Address
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: customer_a, authorize?: true)

      refute address_b.id in Enum.map(results, & &1.id),
             "customer_a should not see customer_b's address"
    end

    test "customer_a can read their own addresses", %{
      customer_a: customer_a,
      store_a: store_a
    } do
      address_a = create_address!(customer_a, store_a)

      results =
        Emakola.Customers.Address
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: customer_a, authorize?: true)

      assert address_a.id in Enum.map(results, & &1.id),
             "customer_a should be able to read their own address"
    end
  end

  # ---------------------------------------------------------------------------
  # Customer self-read scoping (PII: other customers' names/emails/tags)
  # ---------------------------------------------------------------------------

  describe "Finding 2 — Customer actor self-read scoping" do
    setup :setup_two_customers

    test "customer_a cannot read customer_b's profile", %{
      customer_a: customer_a,
      customer_b: customer_b,
      store_a: store_a
    } do
      results =
        Emakola.Customers.Customer
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: customer_a, authorize?: true)

      refute customer_b.id in Enum.map(results, & &1.id),
             "customer_a should not see customer_b's profile"
    end

    test "customer_a can read their own profile", %{
      customer_a: customer_a,
      store_a: store_a
    } do
      results =
        Emakola.Customers.Customer
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: customer_a, authorize?: true)

      assert customer_a.id in Enum.map(results, & &1.id),
             "customer_a should be able to read their own record"
    end
  end

  # ---------------------------------------------------------------------------
  # Payment — customers must NOT be able to read payments directly
  # (no customer_id on Payment; gateway responses contain sensitive data)
  # ---------------------------------------------------------------------------

  describe "Finding 2 — Payment: customer actor denied" do
    setup :setup_two_customers

    test "customer actor cannot read payments directly", %{
      customer_a: customer_a,
      store_a: store_a
    } do
      create_payment!(store_a)

      Emakola.Payments.Payment
      |> Ash.Query.set_tenant(store_a.id)
      |> assert_no_cross_tenant_leak(customer_a)
    end
  end

  # ---------------------------------------------------------------------------
  # Return row-scoping (customers should only see their own returns)
  # ---------------------------------------------------------------------------

  describe "Finding 2 — Return actor row-scoping for Customer" do
    setup :setup_two_customers

    test "customer_a cannot read customer_b's returns", %{
      customer_a: customer_a,
      customer_b: customer_b,
      store_a: store_a
    } do
      order_b = create_order!(store_a, customer_id: customer_b.id)

      return_b =
        Emakola.Orders.Return
        |> Ash.Changeset.for_create(:request_return, %{
          store_id: store_a.id,
          order_id: order_b.id,
          customer_id: customer_b.id,
          reason: :defective,
          currency: "GHS"
        })
        |> Ash.create!(authorize?: false)

      results =
        Emakola.Orders.Return
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: customer_a, authorize?: true)

      refute return_b.id in Enum.map(results, & &1.id),
             "customer_a should not see customer_b's return"
    end

    test "customer_a can read their own returns", %{
      customer_a: customer_a,
      store_a: store_a
    } do
      order_a = create_order!(store_a, customer_id: customer_a.id)

      return_a =
        Emakola.Orders.Return
        |> Ash.Changeset.for_create(:request_return, %{
          store_id: store_a.id,
          order_id: order_a.id,
          customer_id: customer_a.id,
          reason: :changed_mind,
          currency: "GHS"
        })
        |> Ash.create!(authorize?: false)

      results =
        Emakola.Orders.Return
        |> Ash.Query.set_tenant(store_a.id)
        |> Ash.read!(actor: customer_a, authorize?: true)

      assert return_a.id in Enum.map(results, & &1.id),
             "customer_a should be able to read their own return"
    end
  end

  # ---------------------------------------------------------------------------
  # Coupon — customer actor must not have blanket coupon reads
  # (public coupons are accessible only via specific action bypasses)
  # ---------------------------------------------------------------------------

  describe "Finding 2 — Coupon: customer actor denied for default read" do
    setup :setup_two_customers

    test "customer actor cannot list all coupons via default :read", %{
      customer_a: customer_a,
      store_a: store_a
    } do
      Emakola.Marketing.Coupon
      |> Ash.Changeset.for_create(:create, %{
        store_id: store_a.id,
        code: "SECRET#{System.unique_integer([:positive])}",
        discount_type: :percentage,
        discount_value: 1000
      })
      |> Ash.create!(authorize?: false)

      Emakola.Marketing.Coupon
      |> Ash.Query.set_tenant(store_a.id)
      |> assert_no_cross_tenant_leak(customer_a)
    end
  end
end
