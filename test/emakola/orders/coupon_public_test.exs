defmodule Emakola.Marketing.CouponPublicTest do
  @moduledoc """
  Tests for the `is_public` field and `list_active_public` action on Coupon.

  Validates:
  - is_public defaults to false
  - is_public can be set on create and update
  - list_active_public returns only active, public, non-expired, non-maxed coupons
  - list_active_public respects store isolation
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Marketing.Coupon

  setup do
    store = create_store!()
    %{store: store}
  end

  describe "is_public attribute" do
    test "defaults to false on create", %{store: store} do
      {:ok, coupon} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "DEFAULT",
          discount_type: :percentage,
          discount_value: 1000
        })
        |> Ash.create(authorize?: false)

      assert coupon.is_public == false
    end

    test "can be set to true on create", %{store: store} do
      {:ok, coupon} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "PUBLIC1",
          discount_type: :percentage,
          discount_value: 1000,
          is_public: true
        })
        |> Ash.create(authorize?: false)

      assert coupon.is_public == true
    end

    test "can be toggled via update", %{store: store} do
      {:ok, coupon} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "TOGGLE",
          discount_type: :fixed_amount,
          discount_value: 500,
          is_public: false
        })
        |> Ash.create(authorize?: false)

      assert coupon.is_public == false

      {:ok, updated} =
        coupon
        |> Ash.Changeset.for_update(:update, %{is_public: true})
        |> Ash.update(authorize?: false)

      assert updated.is_public == true
    end
  end

  describe "list_active_public action" do
    test "returns active public coupons", %{store: store} do
      create_coupon!(store, %{code: "PUB1", is_public: true, active: true})
      create_coupon!(store, %{code: "PUB2", is_public: true, active: true})

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)

      codes = Enum.map(coupons, & &1.code)
      assert "PUB1" in codes
      assert "PUB2" in codes
    end

    test "excludes non-public coupons", %{store: store} do
      create_coupon!(store, %{code: "PRIVATE", is_public: false, active: true})
      create_coupon!(store, %{code: "SHOWN", is_public: true, active: true})

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)

      codes = Enum.map(coupons, & &1.code)
      assert "SHOWN" in codes
      refute "PRIVATE" in codes
    end

    test "excludes inactive coupons", %{store: store} do
      create_coupon!(store, %{code: "INACTIVE", is_public: true, active: false})

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)
      assert coupons == []
    end

    test "excludes expired coupons", %{store: store} do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      create_coupon!(store, %{code: "EXPIRED", is_public: true, active: true, expires_at: past})

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)
      assert coupons == []
    end

    test "includes coupons with no expiry", %{store: store} do
      create_coupon!(store, %{code: "NOEXP", is_public: true, active: true, expires_at: nil})

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)
      assert length(coupons) == 1
      assert hd(coupons).code == "NOEXP"
    end

    test "excludes coupons that have not started yet", %{store: store} do
      future = DateTime.add(DateTime.utc_now(), 86_400, :second)
      create_coupon!(store, %{code: "FUTURE", is_public: true, active: true, starts_at: future})

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)
      assert coupons == []
    end

    test "includes coupons whose start date has passed", %{store: store} do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      create_coupon!(store, %{code: "STARTED", is_public: true, active: true, starts_at: past})

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)
      assert length(coupons) == 1
    end

    test "excludes coupons that have reached max usage", %{store: store} do
      {:ok, coupon} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "MAXED",
          discount_type: :percentage,
          discount_value: 500,
          is_public: true,
          active: true,
          max_uses: 1
        })
        |> Ash.create(authorize?: false)

      # Increment usage to hit the limit
      {:ok, _} =
        coupon
        |> Ash.Changeset.for_update(:increment_usage, %{})
        |> Ash.update(authorize?: false)

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)
      assert coupons == []
    end

    test "includes coupons with no max usage limit", %{store: store} do
      create_coupon!(store, %{code: "UNLIMITED", is_public: true, active: true, max_uses: nil})

      {:ok, coupons} = Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)
      assert length(coupons) == 1
    end

    test "respects store isolation", %{store: store} do
      other_store = create_store!()

      create_coupon!(store, %{code: "STORE1", is_public: true, active: true})
      create_coupon!(other_store, %{code: "STORE2", is_public: true, active: true})

      {:ok, store1_coupons} =
        Emakola.Marketing.list_active_public_coupons(store.id, authorize?: false)

      {:ok, store2_coupons} = Emakola.Marketing.list_active_public_coupons(other_store.id)

      codes1 = Enum.map(store1_coupons, & &1.code)
      codes2 = Enum.map(store2_coupons, & &1.code)

      assert "STORE1" in codes1
      refute "STORE2" in codes1
      assert "STORE2" in codes2
      refute "STORE1" in codes2
    end
  end

  # -- Test Helpers --

  defp create_coupon!(store, attrs) do
    default = %{
      store_id: store.id,
      discount_type: :percentage,
      discount_value: 1000
    }

    params = Map.merge(default, Map.new(attrs))

    Coupon
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end
end
