defmodule Emakola.Orders.SusuPlanTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.SusuPlan

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create!(store, attrs) do
    attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline())

    SusuPlan
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  test "custom plan gets an 8-char code, pending status, and defaults" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 200_000})

    assert String.match?(plan.code, ~r/^[a-z2-7]{8}$/)
    assert plan.status == :pending
    assert plan.quantity == 1
    assert plan.min_chunk == 1_000
    assert plan.contributed_amount == 0
    assert plan.stock_reserved == false
    assert plan.customer_id == nil
    assert plan.fee_rate_bps == 200
  end

  test "catalog plan keeps its variant and quantity" do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store)
    variant = Emakola.Factory.create_variant!(product, store)

    plan =
      create!(store, %{
        type: :catalog,
        variant_id: variant.id,
        quantity: 3,
        total_amount: 15_000
      })

    assert plan.variant_id == variant.id
    assert plan.quantity == 3
  end

  test "catalog plan requires variant_id; custom requires title" do
    store = Emakola.Factory.create_store!()

    assert {:error, _} =
             SusuPlan
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               type: :catalog,
               total_amount: 15_000,
               deadline: future_deadline()
             })
             |> Ash.create(authorize?: false)

    assert {:error, _} =
             SusuPlan
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               type: :custom,
               total_amount: 15_000,
               deadline: future_deadline()
             })
             |> Ash.create(authorize?: false)
  end

  test "catalog plan's variant_id must belong to the tenant" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store_b)
    variant = Emakola.Factory.create_variant!(product, store_b)

    assert {:error, %Ash.Error.Invalid{}} =
             SusuPlan
             |> Ash.Changeset.for_create(:create, %{
               store_id: store_a.id,
               type: :catalog,
               variant_id: variant.id,
               total_amount: 15_000,
               deadline: future_deadline()
             })
             |> Ash.create(authorize?: false)
  end

  test "total_amount must be at least 100" do
    store = Emakola.Factory.create_store!()

    assert {:error, %Ash.Error.Invalid{}} =
             SusuPlan
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               type: :custom,
               title: "Cheap",
               total_amount: 99,
               deadline: future_deadline()
             })
             |> Ash.create(authorize?: false)
  end

  test "min_chunk must be greater than 0" do
    store = Emakola.Factory.create_store!()

    assert {:error, %Ash.Error.Invalid{}} =
             SusuPlan
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               type: :custom,
               title: "Fridge",
               total_amount: 15_000,
               min_chunk: 0,
               deadline: future_deadline()
             })
             |> Ash.create(authorize?: false)
  end

  test "deadline must be in the future" do
    store = Emakola.Factory.create_store!()

    assert {:error, %Ash.Error.Invalid{}} =
             SusuPlan
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               type: :custom,
               title: "Fridge",
               total_amount: 15_000,
               deadline: DateTime.add(DateTime.utc_now(), -1, :day)
             })
             |> Ash.create(authorize?: false)
  end

  test "the code unique index spans every store — get_by_code has no tenant to disambiguate with" do
    result =
      Emakola.Repo.query!(
        """
        SELECT indexdef FROM pg_indexes
        WHERE tablename = 'susu_plans' AND indexname = 'susu_plans_unique_code_index'
        """,
        []
      )

    assert [[indexdef]] = result.rows
    assert indexdef =~ "UNIQUE"

    refute indexdef =~ "store_id",
           "unique_code must stay all_tenants?: true — a per-store index would let " <>
             "two stores mint the same code and crash get_by_code's get?(true)"
  end

  test "tenant isolation: store B cannot read store A's plan by code" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()
    plan = create!(store_a, %{type: :custom, title: "Fridge", total_amount: 15_000})

    assert {:ok, []} =
             SusuPlan
             |> Ash.Query.for_read(:get_by_code, %{code: plan.code})
             |> Ash.Query.set_tenant(store_b.id)
             |> Ash.read(authorize?: false)
  end

  test "activate transitions pending to active and stores customer + delivery address" do
    store = Emakola.Factory.create_store!()
    customer = Emakola.Factory.create_customer!(store)
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    updated =
      plan
      |> Ash.Changeset.for_update(:activate, %{
        customer_id: customer.id,
        delivery_address: %{"city" => "Accra"}
      })
      |> Ash.update!(authorize?: false)

    assert updated.status == :active
    assert updated.customer_id == customer.id
    assert updated.delivery_address == %{"city" => "Accra"}
  end

  test "activate rejects a plan that is not pending" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    cancelled =
      plan
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             cancelled
             |> Ash.Changeset.for_update(:activate, %{})
             |> Ash.update(authorize?: false)
  end

  test "record_contribution atomically adds amount_delta while active" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    once =
      active
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 5_000})
      |> Ash.update!(authorize?: false)

    assert once.contributed_amount == 5_000

    twice =
      once
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 3_000})
      |> Ash.update!(authorize?: false)

    assert twice.contributed_amount == 8_000
  end

  test "record_contribution rejects a non-positive amount_delta (TC-3 Task 3 defensive guard)" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             active
             |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 0})
             |> Ash.update(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             active
             |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: -1_000})
             |> Ash.update(authorize?: false)
  end

  test "record_contribution rejects a plan that is not active" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    assert {:error, %Ash.Error.Invalid{}} =
             plan
             |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 1_000})
             |> Ash.update(authorize?: false)
  end

  test "complete transitions active to completed only at the exact total" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    partially_paid =
      active
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 10_000})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             partially_paid
             |> Ash.Changeset.for_update(:complete, %{})
             |> Ash.update(authorize?: false)

    fully_paid =
      partially_paid
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 5_000})
      |> Ash.update!(authorize?: false)

    completed =
      fully_paid
      |> Ash.Changeset.for_update(:complete, %{})
      |> Ash.update!(authorize?: false)

    assert completed.status == :completed
  end

  test "cancel transitions pending or active to cancelled, and rejects from completed" do
    store = Emakola.Factory.create_store!()

    pending = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    cancelled_from_pending =
      pending
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

    assert cancelled_from_pending.status == :cancelled

    active_plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    active =
      active_plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    cancelled_from_active =
      active
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

    assert cancelled_from_active.status == :cancelled

    completed_plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    completed =
      completed_plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 15_000})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:complete, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             completed
             |> Ash.Changeset.for_update(:cancel, %{})
             |> Ash.update(authorize?: false)
  end

  test "expire transitions active to expired, and rejects from pending" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    assert {:error, %Ash.Error.Invalid{}} =
             plan
             |> Ash.Changeset.for_update(:expire, %{})
             |> Ash.update(authorize?: false)

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    expired =
      active
      |> Ash.Changeset.for_update(:expire, %{})
      |> Ash.update!(authorize?: false)

    assert expired.status == :expired
  end

  test "extend_deadline only works while active, and only forward" do
    store = Emakola.Factory.create_store!()
    original_deadline = future_deadline(10)

    plan =
      create!(store, %{
        type: :custom,
        title: "Fridge",
        total_amount: 15_000,
        deadline: original_deadline
      })

    assert {:error, %Ash.Error.Invalid{}} =
             plan
             |> Ash.Changeset.for_update(:extend_deadline, %{deadline: future_deadline(20)})
             |> Ash.update(authorize?: false)

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             active
             |> Ash.Changeset.for_update(:extend_deadline, %{deadline: future_deadline(5)})
             |> Ash.update(authorize?: false)

    extended =
      active
      |> Ash.Changeset.for_update(:extend_deadline, %{deadline: future_deadline(20)})
      |> Ash.update!(authorize?: false)

    assert_in_delta DateTime.diff(extended.deadline, future_deadline(20), :second), 0, 2
  end

  test "update_delivery only works while active" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    assert {:error, %Ash.Error.Invalid{}} =
             plan
             |> Ash.Changeset.for_update(:update_delivery, %{
               delivery_address: %{"city" => "Kumasi"}
             })
             |> Ash.update(authorize?: false)

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    updated =
      active
      |> Ash.Changeset.for_update(:update_delivery, %{delivery_address: %{"city" => "Kumasi"}})
      |> Ash.update!(authorize?: false)

    assert updated.delivery_address == %{"city" => "Kumasi"}
  end

  test "usable_for_start?/1 is true only while pending and before the deadline" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    assert SusuPlan.usable_for_start?(plan)

    past_deadline = %{plan | deadline: DateTime.add(DateTime.utc_now(), -1, :day)}
    refute SusuPlan.usable_for_start?(past_deadline)

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    refute SusuPlan.usable_for_start?(active)
  end

  test "remaining/1 is total_amount minus contributed_amount" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    assert SusuPlan.remaining(plan) == 15_000

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    contributed =
      active
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 4_000})
      |> Ash.update!(authorize?: false)

    assert SusuPlan.remaining(contributed) == 11_000
  end

  test "chunk_bounds/1 clamps between min_chunk and remaining, collapsing when remaining < min_chunk" do
    store = Emakola.Factory.create_store!()

    plan =
      create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000, min_chunk: 5_000})

    assert SusuPlan.chunk_bounds(plan) == %{min: 5_000, max: 15_000}

    active =
      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    almost_done =
      active
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 12_000})
      |> Ash.update!(authorize?: false)

    # remaining is 3_000, below the 5_000 min_chunk — min collapses to remaining
    # so the final chunk can land exactly on the total.
    assert SusuPlan.chunk_bounds(almost_done) == %{min: 3_000, max: 3_000}
  end

  # ── Task 8: notification dedup timestamps ──────────────────────

  test "mark_nudged stamps last_nudged_at" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    refute plan.last_nudged_at

    nudged = plan |> Ash.Changeset.for_update(:mark_nudged, %{}) |> Ash.update!(authorize?: false)

    assert %DateTime{} = nudged.last_nudged_at
  end

  test "mark_warned_7d stamps warned_7d_at" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    refute plan.warned_7d_at

    warned =
      plan |> Ash.Changeset.for_update(:mark_warned_7d, %{}) |> Ash.update!(authorize?: false)

    assert %DateTime{} = warned.warned_7d_at
    refute warned.warned_1d_at
  end

  test "mark_warned_1d stamps warned_1d_at" do
    store = Emakola.Factory.create_store!()
    plan = create!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    refute plan.warned_1d_at

    warned =
      plan |> Ash.Changeset.for_update(:mark_warned_1d, %{}) |> Ash.update!(authorize?: false)

    assert %DateTime{} = warned.warned_1d_at
    refute warned.warned_7d_at
  end

  # ── Task 9: admin listing ──────────────────────────────────────

  test "list_for_admin sorts newest first and is tenant-scoped" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()

    older = create!(store_a, %{type: :custom, title: "Older", total_amount: 15_000})
    newer = create!(store_a, %{type: :custom, title: "Newer", total_amount: 15_000})
    _other_store_plan = create!(store_b, %{type: :custom, title: "Foreign", total_amount: 15_000})

    plans =
      SusuPlan
      |> Ash.Query.for_read(:list_for_admin)
      |> Ash.read!(authorize?: false, tenant: store_a.id)

    assert Enum.map(plans, & &1.id) == [newer.id, older.id]
  end
end
