defmodule Emakola.Marketing.CouponTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Marketing.Coupon

  setup do
    store = create_store!()
    %{store: store}
  end

  describe "create" do
    test "creates a coupon with valid attributes", %{store: store} do
      assert {:ok, coupon} =
               Coupon
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 code: "SAVE10",
                 discount_type: :percentage,
                 discount_value: 1000,
                 active: true
               })
               |> Ash.create(authorize?: false)

      assert coupon.code == "SAVE10"
      assert coupon.discount_type == :percentage
      assert coupon.discount_value == 1000
      assert coupon.uses_count == 0
      assert coupon.active == true
    end

    test "upcases code on create", %{store: store} do
      assert {:ok, coupon} =
               Coupon
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 code: "lowercase",
                 discount_type: :fixed_amount,
                 discount_value: 500
               })
               |> Ash.create(authorize?: false)

      assert coupon.code == "LOWERCASE"
    end

    test "enforces unique code per store", %{store: store} do
      attrs = %{
        store_id: store.id,
        code: "UNIQUE1",
        discount_type: :fixed_amount,
        discount_value: 500
      }

      {:ok, _} =
        Coupon |> Ash.Changeset.for_create(:create, attrs) |> Ash.create(authorize?: false)

      assert {:error, _} =
               Coupon |> Ash.Changeset.for_create(:create, attrs) |> Ash.create(authorize?: false)
    end

    test "allows same code in different stores", %{store: store} do
      other_store = create_store!()

      attrs = %{code: "SHARED", discount_type: :percentage, discount_value: 500}

      {:ok, _} =
        Coupon
        |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
        |> Ash.create(authorize?: false)

      {:ok, _} =
        Coupon
        |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, other_store.id))
        |> Ash.create(authorize?: false)
    end

    test "validates percentage <= 10000 (100%)", %{store: store} do
      assert {:error, _} =
               Coupon
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 code: "TOOMUCH",
                 discount_type: :percentage,
                 discount_value: 15_000
               })
               |> Ash.create(authorize?: false)
    end

    test "creates free_shipping coupon without discount_value", %{store: store} do
      assert {:ok, coupon} =
               Coupon
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 code: "FREESHIP",
                 discount_type: :free_shipping
               })
               |> Ash.create(authorize?: false)

      assert coupon.discount_type == :free_shipping
      assert coupon.discount_value == 0
    end

    test "creates coupon with all optional fields", %{store: store} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      future = DateTime.add(now, 86_400)

      assert {:ok, coupon} =
               Coupon
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 code: "FULL",
                 description: "Full featured coupon",
                 discount_type: :percentage,
                 discount_value: 2000,
                 max_discount_amount: 50_000,
                 minimum_order_amount: 10_000,
                 max_uses: 100,
                 starts_at: now,
                 expires_at: future
               })
               |> Ash.create(authorize?: false)

      assert coupon.description == "Full featured coupon"
      assert coupon.max_discount_amount == 50_000
      assert coupon.minimum_order_amount == 10_000
      assert coupon.max_uses == 100
      assert coupon.starts_at == now
      assert coupon.expires_at == future
    end
  end

  describe "find_by_code" do
    test "finds coupon by store and code", %{store: store} do
      {:ok, created} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "FIND_ME",
          discount_type: :fixed_amount,
          discount_value: 2000
        })
        |> Ash.create(authorize?: false)

      assert {:ok, [found]} =
               Coupon
               |> Ash.Query.for_read(:find_by_code, %{store_id: store.id, code: "FIND_ME"})
               |> Ash.read(authorize?: false)

      assert found.id == created.id
    end

    test "finds coupon case-insensitively", %{store: store} do
      {:ok, created} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "UPPER",
          discount_type: :percentage,
          discount_value: 500
        })
        |> Ash.create(authorize?: false)

      assert {:ok, [found]} =
               Coupon
               |> Ash.Query.for_read(:find_by_code, %{store_id: store.id, code: "upper"})
               |> Ash.read(authorize?: false)

      assert found.id == created.id
    end

    test "returns empty when code not in store", %{store: store} do
      other_store = create_store!()

      {:ok, _} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: other_store.id,
          code: "OTHER",
          discount_type: :fixed_amount,
          discount_value: 1000
        })
        |> Ash.create(authorize?: false)

      assert {:ok, []} =
               Coupon
               |> Ash.Query.for_read(:find_by_code, %{store_id: store.id, code: "OTHER"})
               |> Ash.read(authorize?: false)
    end
  end

  describe "increment_usage" do
    test "atomically increments uses_count", %{store: store} do
      {:ok, coupon} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "COUNT1",
          discount_type: :percentage,
          discount_value: 500,
          max_uses: 10
        })
        |> Ash.create(authorize?: false)

      assert coupon.uses_count == 0

      {:ok, updated} =
        coupon
        |> Ash.Changeset.for_update(:increment_usage, %{})
        |> Ash.update(authorize?: false)

      assert updated.uses_count == 1
    end
  end

  describe "deactivate" do
    test "sets active to false", %{store: store} do
      {:ok, coupon} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "DEACT1",
          discount_type: :fixed_amount,
          discount_value: 1000
        })
        |> Ash.create(authorize?: false)

      assert coupon.active == true

      {:ok, deactivated} =
        coupon
        |> Ash.Changeset.for_update(:deactivate, %{})
        |> Ash.update(authorize?: false)

      assert deactivated.active == false
    end
  end

  describe "list_by_store" do
    test "lists coupons for a specific store", %{store: store} do
      other_store = create_store!()

      {:ok, _} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "MINE1",
          discount_type: :percentage,
          discount_value: 500
        })
        |> Ash.create(authorize?: false)

      {:ok, _} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: other_store.id,
          code: "THEIRS",
          discount_type: :percentage,
          discount_value: 500
        })
        |> Ash.create(authorize?: false)

      assert {:ok, coupons} =
               Coupon
               |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
               |> Ash.read(authorize?: false)

      assert length(coupons) == 1
      assert hd(coupons).code == "MINE1"
    end
  end
end
