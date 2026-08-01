defmodule Emakola.Orders.SusuStockTest do
  @moduledoc """
  TC-3 Task 4: stock is decremented once, at susu-plan activation
  (`SusuStock.reserve/1`), re-incremented on release, and never
  double-decremented when the plan's order later confirms
  (`Orders.Changes.DecrementStock` skips susu orders — pinned below).
  """

  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Orders.{SusuPlan, SusuStock}

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create_plan!(store, attrs) do
    attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline())

    SusuPlan
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  defp reload_variant(variant),
    do: Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)

  defp reload_plan(plan), do: Ash.get!(SusuPlan, plan.id, authorize?: false)

  setup do
    store = Factory.create_store!()
    product = Factory.create_product!(store)
    %{store: store, product: product}
  end

  describe "reserve/1" do
    test "decrements a tracked catalog variant's stock by plan.quantity exactly once", %{
      store: store,
      product: product
    } do
      variant = Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 15_000
        })

      assert :ok = SusuStock.reserve(plan)

      assert reload_variant(variant).stock_quantity == 7
      assert reload_plan(plan).stock_reserved == true
    end

    test "insufficient stock returns an error and decrements nothing", %{
      store: store,
      product: product
    } do
      variant = Factory.create_variant!(product, store, stock_quantity: 2, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 15_000
        })

      assert {:error, :insufficient_stock} = SusuStock.reserve(plan)

      assert reload_variant(variant).stock_quantity == 2
      assert reload_plan(plan).stock_reserved == false
    end

    test "untracked variant is a no-op", %{store: store, product: product} do
      variant =
        Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: false)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 15_000
        })

      assert :ok = SusuStock.reserve(plan)

      assert reload_variant(variant).stock_quantity == 10
      assert reload_plan(plan).stock_reserved == false
    end

    test "custom plan is a no-op", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 200_000})

      assert :ok = SusuStock.reserve(plan)
      assert reload_plan(plan).stock_reserved == false
    end
  end

  describe "release/1" do
    test "re-increments only when stock_reserved is true", %{store: store, product: product} do
      variant = Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 15_000
        })

      :ok = SusuStock.reserve(plan)
      plan = reload_plan(plan)

      assert :ok = SusuStock.release(plan)

      assert reload_variant(variant).stock_quantity == 10
      assert reload_plan(plan).stock_reserved == false
    end

    test "double release only increments once (idempotent)", %{store: store, product: product} do
      variant = Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 15_000
        })

      :ok = SusuStock.reserve(plan)
      plan = reload_plan(plan)

      assert :ok = SusuStock.release(plan)
      assert :ok = SusuStock.release(plan)

      assert reload_variant(variant).stock_quantity == 10
    end

    test "no-op when stock was never reserved", %{store: store, product: product} do
      variant = Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 15_000
        })

      assert :ok = SusuStock.release(plan)
      assert reload_variant(variant).stock_quantity == 10
    end
  end

  describe "reserved_quantities_by_variant/1" do
    test "sums quantity across active catalog plans for the same variant", %{
      store: store,
      product: product
    } do
      variant = Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan_a =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 2,
          total_amount: 5_000
        })
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!(authorize?: false)

      plan_b =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 5_000
        })
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!(authorize?: false)

      assert plan_a.status == :active
      assert plan_b.status == :active

      assert SusuStock.reserved_quantities_by_variant(store.id) == %{variant.id => 5}
    end

    test "excludes pending, completed, expired, and cancelled plans", %{
      store: store,
      product: product
    } do
      variant = Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      _pending =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 9,
          total_amount: 5_000
        })

      cancelled =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 9,
          total_amount: 5_000
        })

      cancelled
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

      assert SusuStock.reserved_quantities_by_variant(store.id) == %{}
    end

    test "excludes custom plans and is tenant-scoped", %{store: store, product: product} do
      _variant =
        Factory.create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      _custom_active =
        create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 5_000})
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!(authorize?: false)

      other_store = Factory.create_store!()
      other_product = Factory.create_product!(other_store)

      other_variant =
        Factory.create_variant!(other_product, other_store,
          stock_quantity: 10,
          track_inventory: true
        )

      create_plan!(other_store, %{
        type: :catalog,
        variant_id: other_variant.id,
        quantity: 4,
        total_amount: 5_000
      })
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

      assert SusuStock.reserved_quantities_by_variant(store.id) == %{}
      assert SusuStock.reserved_quantities_by_variant(other_store.id) == %{other_variant.id => 4}
    end
  end

  describe "DecrementStock skips susu orders" do
    test "an order with susu_plan_id set does not decrement stock again on confirm", %{
      store: store,
      product: product
    } do
      variant = Factory.create_variant!(product, store, stock_quantity: 7, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 15_000
        })

      order = Factory.create_order!(store, susu_plan_id: plan.id)

      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 3
      })
      |> Ash.create!(authorize?: false)

      order
      |> Ash.Changeset.for_update(:confirm, %{})
      |> Ash.update!(authorize?: false)

      assert reload_variant(variant).stock_quantity == 7
    end
  end
end
