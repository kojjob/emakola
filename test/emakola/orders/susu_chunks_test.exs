defmodule Emakola.Orders.SusuChunksTest do
  @moduledoc """
  TC-3 Task 3: chunk initiation + webhook accumulation — the money core of
  susu. Binding ordering note: activation calls Task 4's REAL
  `SusuStock.reserve/1` (not mocked); completion enqueues Task 5's
  (not-yet-implemented) `SusuCompletionWorker` shell — this task asserts
  only that it gets enqueued (`assert_enqueued`).
  """

  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Orders.{SusuChunks, SusuPlan}
  alias Emakola.Payments.Payment
  alias Emakola.Payments.Gateways.Mock
  alias Emakola.Payments.Workers.SusuCompletionWorker

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create_plan!(store, attrs) do
    attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline())

    SusuPlan
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  defp activate!(plan, params \\ %{}) do
    plan |> Ash.Changeset.for_update(:activate, params) |> Ash.update!(authorize?: false)
  end

  defp cancel!(plan) do
    plan |> Ash.Changeset.for_update(:cancel, %{}) |> Ash.update!(authorize?: false)
  end

  defp expire!(plan) do
    plan |> Ash.Changeset.for_update(:expire, %{}) |> Ash.update!(authorize?: false)
  end

  defp contribute!(plan, amount) do
    plan
    |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: amount})
    |> Ash.update!(authorize?: false)
  end

  defp complete!(plan) do
    plan |> Ash.Changeset.for_update(:complete, %{}) |> Ash.update!(authorize?: false)
  end

  # Bypasses the create-time "deadline must be in the future" validation —
  # same force-write trick `Factory.create_order!/2` uses for `status` — to
  # simulate a plan whose deadline has passed while the DB row is still
  # `:active` (the sweep that flips it to `:expired` is a later task's job,
  # not this one's).
  defp force_deadline!(plan, deadline) do
    plan
    |> Ash.Changeset.for_update(:update_delivery, %{delivery_address: plan.delivery_address})
    |> Ash.Changeset.force_change_attribute(:deadline, deadline)
    |> Ash.update!(authorize?: false)
  end

  defp reload_plan(plan), do: Ash.get!(SusuPlan, plan.id, authorize?: false)
  defp reload_payment(payment), do: Ash.get!(Payment, payment.id, authorize?: false)

  defp mark_success!(payment) do
    payment
    |> Ash.Changeset.for_update(:mark_success, %{gateway_response: %{}})
    |> Ash.update!(authorize?: false)
  end

  defp buyer_params, do: %{"name" => "Ama Mensah", "phone" => "0201234567"}

  setup do
    store = create_store!()
    %{store: store}
  end

  describe "locked_plan_query/1" do
    test "holds a FOR UPDATE lock on the susu_plans row" do
      {sql, _params} =
        Ecto.Adapters.SQL.to_sql(
          :all,
          Emakola.Repo,
          SusuChunks.locked_plan_query(Ash.UUID.generate())
        )

      assert sql =~ "FOR UPDATE"
    end
  end

  describe "initiate_chunk/4 — amount clamping" do
    test "below min_chunk is rejected", %{store: store} do
      plan =
        create_plan!(store, %{
          type: :custom,
          title: "Fridge",
          total_amount: 15_000,
          min_chunk: 5_000
        })

      assert {:error, :amount_below_min} =
               SusuChunks.initiate_chunk(plan, 4_000, buyer_params(), Mock)
    end

    test "above remaining is rejected", %{store: store} do
      plan =
        create_plan!(store, %{
          type: :custom,
          title: "Fridge",
          total_amount: 15_000,
          min_chunk: 1_000
        })

      assert {:error, :amount_above_remaining} =
               SusuChunks.initiate_chunk(plan, 20_000, buyer_params(), Mock)
    end

    test "the exact remaining amount (final chunk) succeeds", %{store: store} do
      plan =
        create_plan!(store, %{
          type: :custom,
          title: "Fridge",
          total_amount: 15_000,
          min_chunk: 1_000
        })

      assert {:ok, %{payment: payment, gateway: %{reference: reference}}} =
               SusuChunks.initiate_chunk(plan, 15_000, buyer_params(), Mock)

      assert payment.amount == 15_000
      assert payment.susu_plan_id == plan.id
      assert payment.order_id == nil
      assert payment.status == :pending
      assert payment.payout_held == true
      assert payment.payout_hold_reason == "susu_plan"
      assert payment.gateway_reference == reference
      assert payment.metadata["susu_buyer"] == buyer_params()
    end
  end

  describe "initiate_chunk/4 — one pending chunk" do
    test "a second initiation while one chunk is pending is rejected", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

      assert {:ok, _} = SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)

      assert {:error, :chunk_in_flight} =
               SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)
    end

    test "a fresh initiation is allowed once the pending chunk fails", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

      assert {:ok, %{payment: payment}} =
               SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)

      payment
      |> Ash.Changeset.for_update(:mark_failed, %{gateway_response: %{}})
      |> Ash.update!(authorize?: false)

      assert {:ok, _} = SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)
    end
  end

  describe "initiate_chunk/4 — plan usability" do
    test "rejects a completed plan", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 5_000})
      completed = plan |> activate!() |> contribute!(5_000) |> complete!()

      assert {:error, :completed} =
               SusuChunks.initiate_chunk(completed, 1_000, buyer_params(), Mock)
    end

    test "rejects a cancelled plan", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      cancelled = cancel!(plan)

      assert {:error, :cancelled} =
               SusuChunks.initiate_chunk(cancelled, 1_000, buyer_params(), Mock)
    end

    test "rejects an expired plan", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      expired = plan |> activate!() |> expire!()

      assert {:error, :expired} =
               SusuChunks.initiate_chunk(expired, 1_000, buyer_params(), Mock)
    end

    test "rejects an active plan whose deadline has already passed", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      active = activate!(plan)
      past_due = force_deadline!(active, DateTime.add(DateTime.utc_now(), -1, :day))

      assert {:error, :expired} =
               SusuChunks.initiate_chunk(past_due, 1_000, buyer_params(), Mock)
    end

    test "rejects a plan code that doesn't exist" do
      assert {:error, :plan_not_found} =
               SusuChunks.initiate_chunk("nosuchcode", 1_000, buyer_params(), Mock)
    end
  end

  describe "initiate_chunk/4 — first-chunk buyer details" do
    test "requires name and phone when the plan is still pending", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

      assert {:error, :buyer_details_required} =
               SusuChunks.initiate_chunk(plan, 5_000, %{"name" => "Ama"}, Mock)

      assert {:error, :buyer_details_required} =
               SusuChunks.initiate_chunk(plan, 5_000, %{}, Mock)
    end

    test "a returning chunk on an already-active plan doesn't need buyer details", %{
      store: store
    } do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      {:ok, %{payment: first}} = SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)
      first |> mark_success!() |> SusuChunks.confirm_chunk()

      active_plan = reload_plan(plan)
      assert {:ok, _} = SusuChunks.initiate_chunk(active_plan, 5_000, %{}, Mock)
    end
  end

  describe "confirm_chunk/1 — byte-identical no-op for non-susu payments" do
    test "a plain order payment is untouched", %{store: store} do
      order = create_order!(store)
      payment = create_payment!(store, %{order_id: order.id})

      assert :ok = SusuChunks.confirm_chunk(payment)

      assert reload_payment(payment).metadata == payment.metadata
    end
  end

  describe "confirm_chunk/1 — accumulation + idempotency" do
    test "redelivery of the same confirmed payment counts the contribution once", %{
      store: store
    } do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      {:ok, %{payment: payment}} = SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)
      payment = mark_success!(payment)

      assert :ok = SusuChunks.confirm_chunk(payment)
      assert :ok = SusuChunks.confirm_chunk(payment)

      assert reload_plan(plan).contributed_amount == 5_000
    end

    test "a second, different chunk accumulates on top of the first", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

      {:ok, %{payment: first}} = SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)
      first |> mark_success!() |> SusuChunks.confirm_chunk()

      active_plan = reload_plan(plan)
      {:ok, %{payment: second}} = SusuChunks.initiate_chunk(active_plan, 3_000, %{}, Mock)
      second |> mark_success!() |> SusuChunks.confirm_chunk()

      assert reload_plan(plan).contributed_amount == 8_000
    end
  end

  describe "confirm_chunk/1 — first-chunk activation" do
    test "custom plan: activates, finds/creates the customer by phone, stores delivery address",
         %{store: store} do
      plan =
        create_plan!(store, %{
          type: :custom,
          title: "Fridge",
          total_amount: 15_000,
          collect_delivery: true
        })

      buyer = %{"name" => "Ama Mensah", "phone" => "0201234567", "address" => "12 High St"}
      {:ok, %{payment: payment}} = SusuChunks.initiate_chunk(plan, 5_000, buyer, Mock)
      payment = mark_success!(payment)

      assert :ok = SusuChunks.confirm_chunk(payment)

      updated = reload_plan(plan)
      assert updated.status == :active
      assert updated.contributed_amount == 5_000

      assert updated.delivery_address == %{
               "name" => "Ama Mensah",
               "phone" => "0201234567",
               "address" => "12 High St"
             }

      customer = Ash.get!(Emakola.Customers.Customer, updated.customer_id, authorize?: false)
      assert customer.name == "Ama Mensah"
      assert customer.phone == "0201234567"
    end

    test "catalog plan: reserves stock via SusuStock.reserve/1", %{store: store} do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 2,
          total_amount: 15_000
        })

      {:ok, %{payment: payment}} =
        SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)

      payment = mark_success!(payment)

      assert :ok = SusuChunks.confirm_chunk(payment)

      updated_plan = reload_plan(plan)
      assert updated_plan.status == :active
      assert updated_plan.contributed_amount == 5_000
      assert updated_plan.stock_reserved == true

      updated_variant = Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
      assert updated_variant.stock_quantity == 8
    end

    test "insufficient stock cancels the plan and flags the payment for refund instead of activating",
         %{store: store} do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 0, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 1,
          total_amount: 5_000
        })

      {:ok, %{payment: payment}} =
        SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)

      payment = mark_success!(payment)

      assert :ok = SusuChunks.confirm_chunk(payment)

      updated_plan = reload_plan(plan)
      assert updated_plan.status == :cancelled
      assert updated_plan.contributed_amount == 0

      updated_payment = reload_payment(payment)
      assert updated_payment.metadata["refund_note"] =~ "refund"
      refute updated_payment.metadata["susu_counted"]
    end
  end

  describe "confirm_chunk/1 — dead-plan refund flagging" do
    test "confirming against a cancelled plan flags the payment for refund and never counts it",
         %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      payment = create_payment!(store, %{susu_plan_id: plan.id, amount: 5_000})

      cancel!(plan)

      assert :ok = SusuChunks.confirm_chunk(payment)

      assert reload_plan(plan).contributed_amount == 0

      updated_payment = reload_payment(payment)
      assert updated_payment.metadata["refund_note"] =~ "refund"
      refute updated_payment.metadata["susu_counted"]
    end

    test "flagging the same payment twice doesn't duplicate the note", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      payment = create_payment!(store, %{susu_plan_id: plan.id, amount: 5_000})
      cancel!(plan)

      assert :ok = SusuChunks.confirm_chunk(payment)
      assert :ok = SusuChunks.confirm_chunk(payment)

      note = reload_payment(payment).metadata["refund_note"]
      assert note |> String.split("refund this payment.") |> length() == 2
    end
  end

  describe "confirm_chunk/1 — never overshoots the total" do
    test "a contribution that would exceed the plan's remaining is flagged for refund, not recorded",
         %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 10_000})
      active = activate!(plan, %{})

      first_payment = create_payment!(store, %{susu_plan_id: active.id, amount: 8_000})
      second_payment = create_payment!(store, %{susu_plan_id: active.id, amount: 8_000})

      assert :ok = SusuChunks.confirm_chunk(first_payment)
      assert :ok = SusuChunks.confirm_chunk(second_payment)

      assert reload_plan(plan).contributed_amount == 8_000

      flagged = reload_payment(second_payment)
      assert flagged.metadata["refund_note"] =~ "refund"
      refute flagged.metadata["susu_counted"]

      counted = reload_payment(first_payment)
      assert counted.metadata["susu_counted"] == true
    end
  end

  describe "confirm_chunk/1 — stock reservation retries across confirms" do
    # Simulates a prior confirm that activated the plan (status -> :active)
    # and then crashed/raised before `SusuStock.reserve/1` completed —
    # `stock_reserved` is still `false` on an already-`:active` plan. Built
    # directly (bypassing `SusuChunks` entirely) rather than by injecting a
    # real crash mid-flow, since that's the state such a crash would leave
    # behind either way.
    test "a retried confirm on an already-active, not-yet-reserved catalog plan attempts reservation before recording",
         %{store: store} do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 2,
          total_amount: 15_000
        })

      active = activate!(plan)
      refute active.stock_reserved

      payment = create_payment!(store, %{susu_plan_id: active.id, amount: 5_000})

      assert :ok = SusuChunks.confirm_chunk(payment)

      updated_plan = reload_plan(plan)
      assert updated_plan.stock_reserved == true
      assert updated_plan.contributed_amount == 5_000

      updated_variant = Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
      assert updated_variant.stock_quantity == 8

      updated_payment = reload_payment(payment)
      assert updated_payment.metadata["susu_counted"] == true
    end

    # `SusuStock.reserve/1` only rescues its OWN `Ash.Error.Invalid`
    # (insufficient stock). Anything else it raises — here, `Ash.get!` on a
    # variant deleted since the plan was created — is an infrastructure
    # failure, not a business-rule rejection, and must propagate out of
    # `confirm_chunk/1` so Oban retries the job rather than recording a
    # silent, uncounted success.
    test "a reservation call that raises (not a business-rule rejection) propagates instead of being swallowed",
         %{store: store} do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 2,
          total_amount: 15_000
        })

      active = activate!(plan)
      payment = create_payment!(store, %{susu_plan_id: active.id, amount: 5_000})

      variant |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy!(authorize?: false)

      # `SusuStock.reserve/1` loads the variant with `Ash.get!/3` BEFORE its
      # own narrow `rescue Ash.Error.Invalid` (scoped to the decrement call
      # only) — a missing variant raises `Ash.Error.Invalid` (Ash's error
      # class wrapping the underlying `Ash.Error.Query.NotFound`) straight
      # out of `reserve/1` itself, uncaught.
      assert_raise Ash.Error.Invalid, fn ->
        SusuChunks.confirm_chunk(payment)
      end

      updated_plan = reload_plan(plan)
      assert updated_plan.status == :active
      assert updated_plan.contributed_amount == 0
      assert updated_plan.stock_reserved == false

      updated_payment = reload_payment(payment)
      refute updated_payment.metadata["susu_counted"]
    end
  end

  describe "confirm_chunk/1 — completion" do
    test "the final chunk completes the plan and enqueues SusuCompletionWorker exactly once, even on redelivery",
         %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 5_000})
      {:ok, %{payment: payment}} = SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)
      payment = mark_success!(payment)

      assert :ok = SusuChunks.confirm_chunk(payment)
      assert :ok = SusuChunks.confirm_chunk(payment)

      assert reload_plan(plan).status == :completed

      assert_enqueued(worker: SusuCompletionWorker, args: %{"susu_plan_id" => plan.id})
      assert length(all_enqueued(worker: SusuCompletionWorker)) == 1
    end

    test "a partial contribution does not enqueue completion", %{store: store} do
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      {:ok, %{payment: payment}} = SusuChunks.initiate_chunk(plan, 5_000, buyer_params(), Mock)
      payment = mark_success!(payment)

      assert :ok = SusuChunks.confirm_chunk(payment)

      assert reload_plan(plan).status == :active
      assert all_enqueued(worker: SusuCompletionWorker) == []
    end
  end
end
