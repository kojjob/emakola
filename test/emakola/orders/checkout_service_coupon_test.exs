defmodule Emakola.Orders.CheckoutServiceCouponTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Orders.CheckoutService
  alias Emakola.Marketing.Coupon

  setup do
    store = create_store!()
    %{store: store}
  end

  # -- validate_coupon/3 --------------------------------------------------

  describe "validate_coupon/3" do
    test "validates an active coupon", %{store: store} do
      {:ok, coupon} =
        create_coupon(store, %{
          code: "VALID10",
          discount_type: :percentage,
          discount_value: 1000
        })

      assert {:ok, found} = CheckoutService.validate_coupon(store.id, "valid10", 50_000)
      assert found.id == coupon.id
    end

    test "rejects inactive coupon", %{store: store} do
      {:ok, _} =
        create_coupon(store, %{
          code: "INACTIVE",
          discount_type: :percentage,
          discount_value: 500,
          active: false
        })

      assert {:error, :coupon_inactive} =
               CheckoutService.validate_coupon(store.id, "INACTIVE", 50_000)
    end

    test "rejects expired coupon", %{store: store} do
      {:ok, _} =
        create_coupon(store, %{
          code: "EXPIRED",
          discount_type: :fixed_amount,
          discount_value: 1000,
          expires_at: DateTime.add(DateTime.utc_now(), -3600)
        })

      assert {:error, :coupon_expired} =
               CheckoutService.validate_coupon(store.id, "EXPIRED", 50_000)
    end

    test "rejects coupon not yet started", %{store: store} do
      {:ok, _} =
        create_coupon(store, %{
          code: "FUTURE",
          discount_type: :percentage,
          discount_value: 500,
          starts_at: DateTime.add(DateTime.utc_now(), 86_400)
        })

      assert {:error, :coupon_not_started} =
               CheckoutService.validate_coupon(store.id, "FUTURE", 50_000)
    end

    test "rejects coupon with max uses exceeded", %{store: store} do
      {:ok, coupon} =
        create_coupon(store, %{
          code: "MAXED",
          discount_type: :percentage,
          discount_value: 500,
          max_uses: 1
        })

      coupon |> Ash.Changeset.for_update(:increment_usage, %{}) |> Ash.update!(authorize?: false)

      assert {:error, :coupon_max_uses_reached} =
               CheckoutService.validate_coupon(store.id, "MAXED", 50_000)
    end

    test "rejects coupon when subtotal below minimum", %{store: store} do
      {:ok, _} =
        create_coupon(store, %{
          code: "MINORDER",
          discount_type: :percentage,
          discount_value: 500,
          minimum_order_amount: 100_000
        })

      assert {:error, :coupon_minimum_not_met} =
               CheckoutService.validate_coupon(store.id, "MINORDER", 50_000)
    end

    test "rejects coupon from wrong store", %{store: store} do
      other_store = create_store!()

      {:ok, _} =
        create_coupon(other_store, %{
          code: "WRONG",
          discount_type: :percentage,
          discount_value: 500
        })

      assert {:error, :coupon_not_found} =
               CheckoutService.validate_coupon(store.id, "WRONG", 50_000)
    end

    test "rejects non-existent coupon code", %{store: store} do
      assert {:error, :coupon_not_found} =
               CheckoutService.validate_coupon(store.id, "NOPE", 50_000)
    end

    test "accepts coupon at exact minimum order amount", %{store: store} do
      {:ok, _} =
        create_coupon(store, %{
          code: "EXACT",
          discount_type: :percentage,
          discount_value: 500,
          minimum_order_amount: 50_000
        })

      assert {:ok, _} = CheckoutService.validate_coupon(store.id, "EXACT", 50_000)
    end

    test "accepts coupon with uses below max", %{store: store} do
      {:ok, _} =
        create_coupon(store, %{
          code: "NOTMAX",
          discount_type: :percentage,
          discount_value: 500,
          max_uses: 5
        })

      assert {:ok, _} = CheckoutService.validate_coupon(store.id, "NOTMAX", 50_000)
    end

    test "accepts coupon with nil max_uses (unlimited)", %{store: store} do
      {:ok, _} =
        create_coupon(store, %{
          code: "UNLIMITED",
          discount_type: :percentage,
          discount_value: 500,
          max_uses: nil
        })

      assert {:ok, _} = CheckoutService.validate_coupon(store.id, "UNLIMITED", 50_000)
    end
  end

  # -- calculate_discount/3 -----------------------------------------------

  describe "calculate_discount/3" do
    test "calculates percentage discount" do
      coupon = %{discount_type: :percentage, discount_value: 1000, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 5_000
    end

    test "caps percentage discount with max_discount_amount" do
      coupon = %{discount_type: :percentage, discount_value: 5000, max_discount_amount: 10_000}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 10_000
    end

    test "calculates fixed amount discount" do
      coupon = %{discount_type: :fixed_amount, discount_value: 3000, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 3000
    end

    test "caps fixed amount at subtotal" do
      coupon = %{discount_type: :fixed_amount, discount_value: 100_000, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 50_000
    end

    test "free shipping returns delivery fee" do
      coupon = %{discount_type: :free_shipping, discount_value: 0, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 2500) == 2500
    end

    test "percentage truncates (rounds down) for small amounts" do
      # 15% of 150 pesewas = 22.5 -> truncated to 22
      coupon = %{discount_type: :percentage, discount_value: 1500, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 150, 0) == 22
    end

    test "100% percentage discount equals subtotal" do
      coupon = %{discount_type: :percentage, discount_value: 10_000, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 50_000
    end

    test "percentage discount with max_discount_amount lower than computed" do
      # 50% of 50000 = 25000, but max is 5000
      coupon = %{discount_type: :percentage, discount_value: 5000, max_discount_amount: 5000}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 5000
    end
  end

  # -- Checkout with coupon integration ------------------------------------

  describe "checkout with coupon" do
    setup %{store: store} do
      product = create_product!(store, title: "Coupon Test Product")

      variant =
        create_variant!(product, store, price: 25_000, sku: "CT-001", stock_quantity: 10)

      {:ok, coupon} =
        create_coupon(store, %{
          code: "CHECKOUT10",
          discount_type: :percentage,
          discount_value: 1000,
          max_uses: 5
        })

      %{product: product, variant: variant, coupon: coupon}
    end

    test "applies coupon discount to order total", %{
      store: store,
      variant: variant,
      coupon: coupon
    } do
      items = [%{variant_id: variant.id, quantity: 2}]
      opts = [coupon_id: coupon.id, delivery_fee: 1500]

      assert {:ok, order} = CheckoutService.checkout!(store.id, items, opts)

      # subtotal = 25000 * 2 = 50000
      # discount = 10% of 50000 = 5000
      # total = 50000 + 1500 - 5000 = 46500
      assert order.subtotal == 50_000
      assert order.delivery_fee == 1500
      assert order.discount_amount == 5000
      assert order.coupon_id == coupon.id
      assert order.total == 46_500
    end

    test "increments coupon usage after checkout", %{
      store: store,
      variant: variant,
      coupon: coupon
    } do
      items = [%{variant_id: variant.id, quantity: 1}]
      opts = [coupon_id: coupon.id]

      assert {:ok, _order} = CheckoutService.checkout!(store.id, items, opts)

      updated_coupon =
        Ash.get!(Emakola.Marketing.Coupon, coupon.id, authorize?: false, authorize?: false)

      assert updated_coupon.uses_count == 1
    end

    test "checkout without coupon still works", %{store: store, variant: variant} do
      items = [%{variant_id: variant.id, quantity: 2}]
      opts = [delivery_fee: 2000]

      assert {:ok, order} = CheckoutService.checkout!(store.id, items, opts)

      assert order.subtotal == 50_000
      assert order.delivery_fee == 2000
      assert order.discount_amount == 0
      assert order.coupon_id == nil
      assert order.total == 52_000
    end

    test "rolls back when coupon is invalid at checkout time", %{store: store, variant: variant} do
      {:ok, expired_coupon} =
        create_coupon(store, %{
          code: "EXPIRED_AT_CHECKOUT",
          discount_type: :percentage,
          discount_value: 500,
          expires_at: DateTime.add(DateTime.utc_now(), -3600)
        })

      items = [%{variant_id: variant.id, quantity: 1}]
      opts = [coupon_id: expired_coupon.id]

      assert {:error, :coupon_expired} = CheckoutService.checkout!(store.id, items, opts)

      # Stock should be unchanged (transaction rolled back)
      refreshed =
        Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false, authorize?: false)

      assert refreshed.stock_quantity == 10
    end

    test "checkout with free shipping coupon", %{store: store, variant: variant} do
      {:ok, free_ship} =
        create_coupon(store, %{
          code: "FREESHIP",
          discount_type: :free_shipping
        })

      items = [%{variant_id: variant.id, quantity: 1}]
      opts = [coupon_id: free_ship.id, delivery_fee: 3000]

      assert {:ok, order} = CheckoutService.checkout!(store.id, items, opts)

      # subtotal = 25000, delivery = 3000, discount = 3000 (free shipping)
      # total = 25000 + 3000 - 3000 = 25000
      assert order.subtotal == 25_000
      assert order.delivery_fee == 3000
      assert order.discount_amount == 3000
      assert order.total == 25_000
    end

    test "checkout with fixed amount coupon", %{store: store, variant: variant} do
      {:ok, fixed_coupon} =
        create_coupon(store, %{
          code: "FIXED5",
          discount_type: :fixed_amount,
          discount_value: 5000
        })

      items = [%{variant_id: variant.id, quantity: 1}]
      opts = [coupon_id: fixed_coupon.id]

      assert {:ok, order} = CheckoutService.checkout!(store.id, items, opts)

      assert order.subtotal == 25_000
      assert order.discount_amount == 5000
      assert order.total == 20_000
    end
  end

  # -- Helpers -------------------------------------------------------------

  defp create_coupon(store, attrs) do
    Coupon
    |> Ash.Changeset.for_create(:create, Map.merge(%{store_id: store.id, active: true}, attrs))
    |> Ash.create(authorize?: false)
  end
end
