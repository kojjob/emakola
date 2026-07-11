defmodule Emakola.InventoryDomainTest do
  @moduledoc """
  Multi-location inventory core (TODO architecture item, full scope per
  2026-07-11 decision): Location + StockLevel + StockMovement owned by a
  real `Emakola.Inventory` Ash domain.

  The load-bearing invariant everywhere: `variant.stock_quantity` remains
  the fast-read total and always equals the sum of its stock levels —
  every write funnels through the Inventory context, which adjusts the
  touched level and the variant total in one transaction.
  """

  use Emakola.DataCase, async: true

  require Ash.Query

  alias Emakola.Factory
  alias Emakola.Inventory
  alias Emakola.Inventory.{Location, StockLevel, StockMovement}

  setup do
    {merchant, store} = Factory.create_merchant_with_store!()
    product = Factory.create_product!(store)
    variant = Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: true)
    %{merchant: merchant, store: store, product: product, variant: variant}
  end

  # ── Locations ──────────────────────────────────────────────────

  describe "locations" do
    test "ensure_default_location!/1 creates Main once and is idempotent", %{store: store} do
      location = Inventory.ensure_default_location!(store.id)
      assert location.name == "Main"
      assert location.default
      assert location.store_id == store.id

      assert Inventory.ensure_default_location!(store.id).id == location.id
      assert length(locations_for(store.id)) == 1
    end

    test "a second location can be created; names are unique per store", %{
      merchant: merchant,
      store: store
    } do
      Inventory.ensure_default_location!(store.id)

      assert {:ok, stall} = Inventory.create_location(merchant, store.id, %{name: "Market Stall"})
      refute stall.default

      assert {:error, _} = Inventory.create_location(merchant, store.id, %{name: "Market Stall"})
    end

    test "set_default swaps the flag so exactly one default exists", %{
      merchant: merchant,
      store: store
    } do
      main = Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Inventory.create_location(merchant, store.id, %{name: "Stall"})

      assert {:ok, _} = Inventory.set_default_location(merchant, store.id, stall.id)

      defaults = locations_for(store.id) |> Enum.filter(& &1.default)
      assert [%{id: id}] = defaults
      assert id == stall.id
      refute reload(Location, main.id).default
    end

    test "the default location cannot be deactivated", %{merchant: merchant, store: store} do
      main = Inventory.ensure_default_location!(store.id)

      assert {:error, :default_location} =
               Inventory.deactivate_location(merchant, store.id, main.id)
    end

    test "a location holding stock cannot be deactivated", %{
      merchant: merchant,
      store: store,
      variant: variant
    } do
      Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Inventory.create_location(merchant, store.id, %{name: "Stall"})
      {:ok, _} = Inventory.restock(variant.id, stall.id, 4)

      assert {:error, :location_holds_stock} =
               Inventory.deactivate_location(merchant, store.id, stall.id)
    end

    test "cross-store merchants cannot manage locations", %{store: store} do
      {stranger, _other_store} = Factory.create_merchant_with_store!()
      Inventory.ensure_default_location!(store.id)

      assert {:error, :forbidden} =
               Inventory.create_location(stranger, store.id, %{name: "Nope"})
    end
  end

  # ── Stock writes: the total always equals the sum of levels ────

  describe "restock/3" do
    test "lazily seeds the default level from the variant total on first touch", %{
      store: store,
      variant: variant
    } do
      main = Inventory.ensure_default_location!(store.id)

      {:ok, _} = Inventory.restock(variant.id, main.id, 5)

      assert level_quantity(variant.id, main.id) == 15
      assert reload_variant(variant).stock_quantity == 15
      assert_invariant(variant)

      assert [%{reason: :restock, delta: 5}] = movements(variant.id)
    end

    test "restocking a non-default location leaves the seeded default intact", %{
      merchant: merchant,
      store: store,
      variant: variant
    } do
      main = Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Inventory.create_location(merchant, store.id, %{name: "Stall"})

      {:ok, _} = Inventory.restock(variant.id, stall.id, 7)

      assert level_quantity(variant.id, main.id) == 10
      assert level_quantity(variant.id, stall.id) == 7
      assert reload_variant(variant).stock_quantity == 17
      assert_invariant(variant)
    end
  end

  describe "adjust/4" do
    test "negative adjustment below zero fails atomically and changes nothing", %{
      store: store,
      variant: variant
    } do
      main = Inventory.ensure_default_location!(store.id)

      assert {:error, _} = Inventory.adjust(variant.id, main.id, -25, :adjustment)

      assert level_quantity(variant.id, main.id) in [nil, 10]
      assert reload_variant(variant).stock_quantity == 10
      assert movements(variant.id) == []
    end
  end

  describe "decrement_for_sale!/4" do
    test "takes from the default location first", %{store: store, variant: variant} do
      main = Inventory.ensure_default_location!(store.id)
      order_id = Ash.UUID.generate()

      Inventory.decrement_for_sale!(variant.id, store.id, 4, order_id)

      assert level_quantity(variant.id, main.id) == 6
      assert reload_variant(variant).stock_quantity == 6
      assert_invariant(variant)

      assert [%{reason: :sale, delta: -4, order_id: ^order_id}] = movements(variant.id)
    end

    test "cascades to other active locations by stock descending", %{
      merchant: merchant,
      store: store,
      variant: variant
    } do
      main = Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Inventory.create_location(merchant, store.id, %{name: "Stall"})
      {:ok, kiosk} = Inventory.create_location(merchant, store.id, %{name: "Kiosk"})
      # default seeded at 10; stall 5; kiosk 2 → total 17
      {:ok, _} = Inventory.restock(variant.id, stall.id, 5)
      {:ok, _} = Inventory.restock(variant.id, kiosk.id, 2)

      Inventory.decrement_for_sale!(variant.id, store.id, 14, Ash.UUID.generate())

      assert level_quantity(variant.id, main.id) == 0
      assert level_quantity(variant.id, stall.id) == 1
      assert level_quantity(variant.id, kiosk.id) == 2
      assert reload_variant(variant).stock_quantity == 3
      assert_invariant(variant)
    end

    test "insufficient total raises Ash.Error.Invalid and changes nothing", %{
      store: store,
      variant: variant
    } do
      main = Inventory.ensure_default_location!(store.id)

      assert_raise Ash.Error.Invalid, fn ->
        Inventory.decrement_for_sale!(variant.id, store.id, 11, Ash.UUID.generate())
      end

      assert level_quantity(variant.id, main.id) in [nil, 10]
      assert reload_variant(variant).stock_quantity == 10
      assert movements(variant.id) == []
    end
  end

  describe "transfer/4" do
    test "moves stock between locations without changing the total", %{
      merchant: merchant,
      store: store,
      variant: variant
    } do
      main = Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Inventory.create_location(merchant, store.id, %{name: "Stall"})

      assert {:ok, _} = Inventory.transfer(variant.id, main.id, stall.id, 4)

      assert level_quantity(variant.id, main.id) == 6
      assert level_quantity(variant.id, stall.id) == 4
      assert reload_variant(variant).stock_quantity == 10
      assert_invariant(variant)

      reasons = movements(variant.id) |> Enum.map(&{&1.reason, &1.delta}) |> Enum.sort()
      assert reasons == [{:transfer_in, 4}, {:transfer_out, -4}]
    end

    test "insufficient stock at the source fails without side effects", %{
      merchant: merchant,
      store: store,
      variant: variant
    } do
      main = Inventory.ensure_default_location!(store.id)
      {:ok, stall} = Inventory.create_location(merchant, store.id, %{name: "Stall"})

      assert {:error, _} = Inventory.transfer(variant.id, main.id, stall.id, 25)

      assert level_quantity(variant.id, main.id) in [nil, 10]
      assert reload_variant(variant).stock_quantity == 10
      assert movements(variant.id) == []
    end
  end

  # ── Checkout integration: the DecrementStock contract holds ────

  describe "order confirm decrement" do
    test "an order confirm decrements through the location cascade", %{
      store: store,
      variant: variant
    } do
      Inventory.ensure_default_location!(store.id)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 3}],
          []
        )

      order
      |> Ash.Changeset.for_update(:confirm, %{})
      |> Ash.update!(authorize?: false)

      assert reload_variant(variant).stock_quantity == 7
      assert_invariant(variant)
      assert [%{reason: :sale, delta: -3}] = movements(variant.id)
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp locations_for(store_id) do
    Location
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.read!(authorize?: false)
  end

  defp level_quantity(variant_id, location_id) do
    StockLevel
    |> Ash.Query.filter(variant_id == ^variant_id and location_id == ^location_id)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> nil
      level -> level.quantity
    end
  end

  defp movements(variant_id) do
    StockMovement
    |> Ash.Query.filter(variant_id == ^variant_id)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp reload_variant(variant),
    do: Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)

  defp reload(resource, id), do: Ash.get!(resource, id, authorize?: false)

  defp assert_invariant(variant) do
    total = reload_variant(variant).stock_quantity

    level_sum =
      StockLevel
      |> Ash.Query.filter(variant_id == ^variant.id)
      |> Ash.read!(authorize?: false)
      |> Enum.reduce(0, &(&1.quantity + &2))

    assert total == level_sum,
           "invariant violated: variant total #{total} != level sum #{level_sum}"
  end
end
