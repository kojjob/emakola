defmodule Emakola.Orders.SusuCompletionTest do
  @moduledoc """
  TC-3 Task 5: susu completion — creates the order (catalog + custom lines,
  plan-derived pricing), stamps every contribution, apportions the platform
  fee across them, composes buyer protection, and confirms the order —
  turning a `:completed` susu plan into a real, paid order.
  """

  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  require Ash.Query

  alias Emakola.Notifications.Workers.OrderNotificationWorker
  alias Emakola.Orders.{Order, SusuCompletion, SusuPlan, SusuStock}
  alias Emakola.Payments.{Payment, PlatformFee, ProtectionHold}
  alias Emakola.Payments.Workers.SusuCompletionWorker

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create_plan!(store, attrs) do
    attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline())

    SusuPlan
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  defp activate!(plan, customer) do
    plan
    |> Ash.Changeset.for_update(:activate, %{
      customer_id: customer.id,
      delivery_address: %{
        "name" => "Ama Mensah",
        "phone" => "0201234567",
        "address" => "12 High St, Accra"
      }
    })
    |> Ash.update!(authorize?: false)
  end

  # Creates a :success payment counted toward `plan`, force-stamping a
  # deterministic ascending `inserted_at` (`seq`) so "the last contribution
  # absorbs the remainder" is a stable, order-controlled assertion rather
  # than a real-clock-resolution flake.
  defp create_contribution!(store, plan, amount, seq) do
    payment =
      create_payment!(store, %{
        susu_plan_id: plan.id,
        amount: amount,
        payout_held: true,
        payout_hold_reason: "susu_plan",
        metadata: %{"susu_counted" => true}
      })

    payment
    |> Ash.Changeset.for_update(:mark_success, %{gateway_response: %{}})
    |> Ash.Changeset.force_change_attribute(
      :inserted_at,
      DateTime.add(~U[2026-01-01 00:00:00.000000Z], seq, :second)
    )
    |> Ash.update!(authorize?: false)
  end

  # Builds a fully `:completed` plan whose contributions (`amounts`) sum
  # exactly to `total_amount`. Reserves stock for real
  # (`SusuStock.reserve/1`, Task 4) for `type: :catalog` — mirrors what
  # `SusuChunks.confirm_chunk/1` does at activation in production.
  defp complete_plan!(store, plan_attrs, amounts) do
    customer = create_customer!(store)
    plan = create_plan!(store, plan_attrs)

    if plan.type == :catalog, do: :ok = SusuStock.reserve(plan)

    plan = activate!(plan, customer)

    plan =
      amounts
      |> Enum.with_index()
      |> Enum.reduce(plan, fn {amount, idx}, plan ->
        create_contribution!(store, plan, amount, idx)

        plan
        |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: amount})
        |> Ash.update!(authorize?: false)
      end)

    plan
    |> Ash.Changeset.for_update(:complete, %{})
    |> Ash.update!(authorize?: false)
  end

  defp reload_variant(variant),
    do: Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)

  defp payments_for(plan) do
    Payment
    |> Ash.Query.filter(susu_plan_id == ^plan.id)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp orders_for(plan) do
    Order
    |> Ash.Query.filter(susu_plan_id == ^plan.id)
    |> Ash.read!(authorize?: false)
  end

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
          SusuCompletion.locked_plan_query(Ash.UUID.generate())
        )

      assert sql =~ "FOR UPDATE"
    end
  end

  describe "complete/1 — catalog plan" do
    test "creates a confirmed order, pricing from the plan (not the current catalog price)",
         %{store: store} do
      product = create_product!(store)

      variant =
        create_variant!(product, store, price: 5_000, stock_quantity: 10, track_inventory: true)

      plan =
        complete_plan!(
          store,
          %{type: :catalog, variant_id: variant.id, quantity: 2, total_amount: 10_001},
          [4_001, 3_000, 3_000]
        )

      assert {:ok, order} = SusuCompletion.complete(plan.id)

      assert order.status == :confirmed
      assert order.total == 10_001
      assert order.subtotal == 10_001
      assert order.susu_plan_id == plan.id
      assert order.customer_id == plan.customer_id
      assert order.shipping_address == plan.delivery_address

      [line] =
        Emakola.Orders.LineItem
        |> Ash.Query.filter(order_id == ^order.id)
        |> Ash.read!(authorize?: false)

      # variant.price * quantity (5_000 * 2 = 10_000) would be WRONG — the
      # order must honor the plan's agreed total (10_001), not today's
      # catalog price.
      assert line.line_total == 10_001
      refute line.line_total == variant.price * plan.quantity
    end

    test "does not decrement stock again when the order confirms", %{store: store} do
      product = create_product!(store)

      variant =
        create_variant!(product, store, price: 5_000, stock_quantity: 10, track_inventory: true)

      plan =
        complete_plan!(
          store,
          %{type: :catalog, variant_id: variant.id, quantity: 2, total_amount: 10_000},
          [10_000]
        )

      assert reload_variant(variant).stock_quantity == 8

      assert {:ok, _order} = SusuCompletion.complete(plan.id)

      assert reload_variant(variant).stock_quantity == 8
    end
  end

  describe "complete/1 — custom plan" do
    test "creates a confirmed order via create_custom with plan-derived pricing", %{
      store: store
    } do
      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Custom kente cloth", total_amount: 7_500},
          [7_500]
        )

      assert {:ok, order} = SusuCompletion.complete(plan.id)

      assert order.status == :confirmed
      assert order.total == 7_500

      [line] =
        Emakola.Orders.LineItem
        |> Ash.Query.filter(order_id == ^order.id)
        |> Ash.read!(authorize?: false)

      assert line.product_title == "Custom kente cloth"
      assert line.unit_price == 7_500
      assert line.line_total == 7_500
    end
  end

  describe "complete/1 — contribution stamping" do
    test "stamps order_id onto every counted contribution", %{store: store} do
      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Beaded necklace", total_amount: 9_000},
          [3_000, 3_000, 3_000]
        )

      assert {:ok, order} = SusuCompletion.complete(plan.id)

      payments = payments_for(plan)
      assert length(payments) == 3
      assert Enum.all?(payments, &(&1.order_id == order.id))
    end
  end

  describe "complete/1 — fee apportionment" do
    test "apportions the platform fee across uneven chunks; the last absorbs the remainder", %{
      store: store
    } do
      amounts = [3_333, 3_333, 3_335]

      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Woven basket", total_amount: Enum.sum(amounts)},
          amounts
        )

      assert {:ok, order} = SusuCompletion.complete(plan.id)

      payments = payments_for(plan)
      total_fee = PlatformFee.calculate(order.total, plan.fee_rate_bps).fee

      fees = Enum.map(payments, &(&1.amount - &1.payable_amount))

      assert Enum.sum(fees) == total_fee
      assert Enum.all?(payments, &(&1.payable_amount >= 0))

      provisional = Enum.map(payments, &PlatformFee.calculate(&1.amount, plan.fee_rate_bps).fee)
      remainder = total_fee - Enum.sum(provisional)
      expected_fees = List.update_at(provisional, -1, &(&1 + remainder))

      assert fees == expected_fees
      # Only meaningful when the floors actually differ from an even split —
      # pins that a genuine remainder was absorbed, not a no-op 0.
      assert remainder > 0
    end

    test "a tiny final chunk cannot be pushed to a negative payable — the remainder spills backward",
         %{store: store} do
      # The exact wedge from the final-review: 1049 x 3 + 1 = 3148 @ 200bps.
      # Dumping the whole shortfall on the LAST contribution (the old,
      # buggy behavior) would give the 1-pesewa chunk a fee of 2 and a
      # payable of -1, tripping `assert_invariants!` and stranding the
      # plan (order never created, contributions parked forever).
      amounts = [1_049, 1_049, 1_049, 1]

      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Cutlery set", total_amount: Enum.sum(amounts)},
          amounts
        )

      assert {:ok, order} = SusuCompletion.complete(plan.id)

      payments = payments_for(plan)
      total_fee = PlatformFee.calculate(order.total, plan.fee_rate_bps).fee
      fees = Enum.map(payments, &(&1.amount - &1.payable_amount))

      assert Enum.sum(fees) == total_fee
      assert Enum.all?(payments, &(&1.payable_amount >= 0))

      # The 1-pesewa chunk absorbs only what it can afford (its own
      # amount); the rest of the shortfall spills onto the previous,
      # larger contribution instead of going negative.
      [_first, _second, third, last] = payments
      assert last.payable_amount == 0
      assert third.payable_amount >= 0
    end

    test "uneven chunk sets never produce a negative payable, whatever the split", %{
      store: store
    } do
      # A spread of uneven, non-round splits — none hand-picked to land on
      # an even division of the fee — each asserting the same two
      # invariants `assert_invariants!` enforces at runtime.
      chunk_sets = [
        [3_333, 3_333, 3_335],
        [1, 1, 1, 9_997],
        [7, 13, 5, 4_975],
        [2_501, 2_499, 1, 4_999],
        [9_999, 1],
        [1_049, 1_049, 1_049, 1]
      ]

      Enum.each(chunk_sets, fn amounts ->
        plan =
          complete_plan!(
            store,
            %{type: :custom, title: "Assorted goods", total_amount: Enum.sum(amounts)},
            amounts
          )

        assert {:ok, order} = SusuCompletion.complete(plan.id)

        payments = payments_for(plan)
        total_fee = PlatformFee.calculate(order.total, plan.fee_rate_bps).fee
        fees = Enum.map(payments, &(&1.amount - &1.payable_amount))

        assert Enum.sum(fees) == total_fee
        assert Enum.all?(payments, &(&1.payable_amount >= 0))
      end)
    end
  end

  describe "complete/1 — unprotected store" do
    test "stamps payable_amount at amount-fee and releases the susu_plan hold", %{store: store} do
      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Sandals", total_amount: 9_000},
          [3_000, 3_000, 3_000]
        )

      assert {:ok, _order} = SusuCompletion.complete(plan.id)

      payments = payments_for(plan)

      Enum.each(payments, fn payment ->
        assert payment.payout_held == false
        assert payment.payout_hold_reason == "susu_plan"
        assert payment.payout_released_at
        assert payment.payable_amount
        assert payment.payable_amount < payment.amount
      end)

      [order] = orders_for(plan)

      assert ProtectionHold
             |> Ash.Query.filter(order_id == ^order.id)
             |> Ash.read!(tenant: store.id, authorize?: false) == []
    end
  end

  describe "complete/1 — protected store" do
    test "creates a ProtectionHold per contribution; payments stay held under buyer_protection",
         %{store: _unprotected_store} do
      store = create_store!(%{buyer_protection_enabled: true})

      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Handmade bag", total_amount: 9_000},
          [3_000, 3_000, 3_000]
        )

      assert {:ok, order} = SusuCompletion.complete(plan.id)

      payments = payments_for(plan)
      assert length(payments) == 3

      Enum.each(payments, fn payment ->
        assert payment.payout_held == true
        assert payment.payout_hold_reason == "buyer_protection"
        assert is_nil(payment.payable_amount)

        hold =
          ProtectionHold
          |> Ash.Query.filter(payment_id == ^payment.id)
          |> Ash.read_one!(tenant: store.id, authorize?: false)

        assert hold.order_id == order.id
        assert hold.amount == payment.amount
        assert hold.fee + hold.net == hold.amount
        assert hold.status == :held
      end)
    end
  end

  describe "complete/1 — idempotency" do
    test "running the worker twice creates exactly one order and leaves stamps unchanged", %{
      store: store
    } do
      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Woven mat", total_amount: 6_000},
          [3_000, 3_000]
        )

      job = %Oban.Job{args: %{"susu_plan_id" => plan.id}}

      assert :ok = SusuCompletionWorker.perform(job)
      first_payments = payments_for(plan)

      assert :ok = SusuCompletionWorker.perform(job)
      second_payments = payments_for(plan)

      orders = orders_for(plan)
      assert length(orders) == 1

      [order] = orders
      assert Enum.all?(first_payments, &(&1.order_id == order.id))

      assert Enum.map(first_payments, &{&1.id, &1.payable_amount, &1.payout_held}) ==
               Enum.map(second_payments, &{&1.id, &1.payable_amount, &1.payout_held})
    end
  end

  # ── Task 8: notification wiring ────────────────────────────────

  describe "complete/1 — notification wiring (Task 8)" do
    test "dispatches susu_completed (buyer) and susu_merchant_completed (merchant), order-based",
         %{store: store} do
      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Woven basket", total_amount: 6_000},
          [6_000]
        )

      assert {:ok, order} = SusuCompletion.complete(plan.id)

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{"order_id" => order.id, "event" => "susu_completed"}
      )

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{"order_id" => order.id, "event" => "susu_merchant_completed"}
      )
    end

    test "a re-run (idempotent replay) does not dispatch susu_completed again", %{store: store} do
      plan =
        complete_plan!(
          store,
          %{type: :custom, title: "Woven mat", total_amount: 4_000},
          [4_000]
        )

      assert {:ok, _order} = SusuCompletion.complete(plan.id)
      assert {:ok, _order} = SusuCompletion.complete(plan.id)

      jobs =
        all_enqueued(worker: OrderNotificationWorker)
        |> Enum.filter(&(&1.args["event"] == "susu_completed"))

      assert length(jobs) == 1
    end
  end
end
