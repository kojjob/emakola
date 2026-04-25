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
end
