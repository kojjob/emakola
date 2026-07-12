defmodule Emakola.Shipping.CalculateFeeTest do
  @moduledoc """
  Tests for `Emakola.Shipping.calculate_fee/2` — looks up a delivery
  zone for the store + region pair and returns the fee in pesewas.
  """

  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Shipping
  alias Emakola.Shipping.DeliveryZone

  defp create_zone!(store, attrs) do
    DeliveryZone
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{store_id: store.id}, Map.new(attrs))
    )
    |> Ash.create!(authorize?: false)
  end

  describe "calculate_fee/2" do
    test "returns the active zone fee when region matches a configured zone" do
      store = create_store!()
      _zone = create_zone!(store, name: "Greater Accra", fee: 1500, active: true)

      assert {:ok, 1500} = Shipping.calculate_fee(store.id, "Greater Accra")
    end

    test "is case-insensitive on region name" do
      store = create_store!()
      _zone = create_zone!(store, name: "Ashanti", fee: 2500, active: true)

      assert {:ok, 2500} = Shipping.calculate_fee(store.id, "ashanti")
      assert {:ok, 2500} = Shipping.calculate_fee(store.id, "ASHANTI")
    end

    test "ignores inactive zones" do
      store = create_store!()
      _zone = create_zone!(store, name: "Volta", fee: 4000, active: false)

      assert {:error, :no_zone} = Shipping.calculate_fee(store.id, "Volta")
    end

    test "is scoped per store — does not leak fees across stores" do
      store_a = create_store!()
      store_b = create_store!()

      _zone_a = create_zone!(store_a, name: "Greater Accra", fee: 1000, active: true)
      _zone_b = create_zone!(store_b, name: "Greater Accra", fee: 9000, active: true)

      assert {:ok, 1000} = Shipping.calculate_fee(store_a.id, "Greater Accra")
      assert {:ok, 9000} = Shipping.calculate_fee(store_b.id, "Greater Accra")
    end

    test "returns :no_zone when region has no configured zone" do
      store = create_store!()

      assert {:error, :no_zone} = Shipping.calculate_fee(store.id, "Northern")
    end

    test "matches stored region name with underscores against UI region keys" do
      # Storefronts dispatch region as snake_case ("greater_accra"); zones are
      # stored with human names ("Greater Accra"). The lookup should normalise.
      store = create_store!()
      _zone = create_zone!(store, name: "Greater Accra", fee: 1500, active: true)

      assert {:ok, 1500} = Shipping.calculate_fee(store.id, "greater_accra")
    end
  end

  describe "calculate_fee/3 with cart context" do
    test "flat zone ignores subtotal and weight context (regression)" do
      store = create_store!()
      _zone = create_zone!(store, name: "Greater Accra", fee: 1500, active: true)

      assert {:ok, 1500} =
               Shipping.calculate_fee(store.id, "Greater Accra",
                 subtotal_pesewas: 999_999,
                 total_weight_grams: 5_000
               )
    end

    test "ships free when subtotal reaches the free-above threshold" do
      store = create_store!()

      _zone =
        create_zone!(store,
          name: "Greater Accra",
          fee: 1500,
          free_above_pesewas: 20_000,
          active: true
        )

      assert {:ok, 0} =
               Shipping.calculate_fee(store.id, "Greater Accra", subtotal_pesewas: 20_000)
    end

    test "charges the base fee when subtotal is below the free-above threshold" do
      store = create_store!()

      _zone =
        create_zone!(store,
          name: "Greater Accra",
          fee: 1500,
          free_above_pesewas: 20_000,
          active: true
        )

      assert {:ok, 1500} =
               Shipping.calculate_fee(store.id, "Greater Accra", subtotal_pesewas: 19_999)
    end

    test "free-above zone without subtotal context behaves flat (2-arity delegation)" do
      store = create_store!()

      _zone =
        create_zone!(store,
          name: "Greater Accra",
          fee: 1500,
          free_above_pesewas: 20_000,
          active: true
        )

      assert {:ok, 1500} = Shipping.calculate_fee(store.id, "Greater Accra")
    end

    test "adds per-kg surcharge rounding weight up to the next kg" do
      store = create_store!()

      _zone =
        create_zone!(store,
          name: "Greater Accra",
          fee: 1500,
          per_kg_fee_pesewas: 500,
          active: true
        )

      # 1001g rounds up to 2kg -> 1500 + 2 * 500
      assert {:ok, 2500} =
               Shipping.calculate_fee(store.id, "Greater Accra", total_weight_grams: 1001)
    end

    test "an exact kg boundary does not round up an extra kg" do
      store = create_store!()

      _zone =
        create_zone!(store,
          name: "Greater Accra",
          fee: 1500,
          per_kg_fee_pesewas: 500,
          active: true
        )

      assert {:ok, 2000} =
               Shipping.calculate_fee(store.id, "Greater Accra", total_weight_grams: 1000)
    end

    test "zero total weight adds no surcharge" do
      store = create_store!()

      _zone =
        create_zone!(store,
          name: "Greater Accra",
          fee: 1500,
          per_kg_fee_pesewas: 500,
          active: true
        )

      assert {:ok, 1500} =
               Shipping.calculate_fee(store.id, "Greater Accra", total_weight_grams: 0)
    end

    test "per-kg zone without weight context behaves flat (2-arity delegation)" do
      store = create_store!()

      _zone =
        create_zone!(store,
          name: "Greater Accra",
          fee: 1500,
          per_kg_fee_pesewas: 500,
          active: true
        )

      assert {:ok, 1500} = Shipping.calculate_fee(store.id, "Greater Accra")
    end

    test "free-above wins over the weight surcharge" do
      store = create_store!()

      _zone =
        create_zone!(store,
          name: "Greater Accra",
          fee: 1500,
          free_above_pesewas: 20_000,
          per_kg_fee_pesewas: 500,
          active: true
        )

      assert {:ok, 0} =
               Shipping.calculate_fee(store.id, "Greater Accra",
                 subtotal_pesewas: 25_000,
                 total_weight_grams: 5_000
               )
    end
  end

  describe "total_weight_grams/1" do
    test "sums weight x quantity, counting nil-weight variants as 0" do
      items = [
        %{weight_grams: 250, quantity: 2},
        %{weight_grams: nil, quantity: 3},
        %{weight_grams: 100, quantity: 1}
      ]

      assert Shipping.total_weight_grams(items) == 600
    end

    test "an empty cart weighs 0" do
      assert Shipping.total_weight_grams([]) == 0
    end
  end
end
