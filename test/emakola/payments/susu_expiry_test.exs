defmodule Emakola.Payments.SusuExpiryTest do
  @moduledoc """
  TC-3 Task 6: the expiry/cancel engine + order-less contribution refunds.

  `SusuLifecycle.cancel/2` and `.expire/1` are the one convergent
  end-of-life path (transition, stock release, refund every counted
  contribution); `SusuRefunds.refund_all_contributions/1` is the
  claim-disciplined refund engine underneath it (mirrors
  `RefundService`'s claim + "no blind retry" semantics, without a
  `Return` — susu contributions are refunded pre-order);
  `SusuExpiryWorker` is the hourly sweep that finds due plans (skipping
  in-flight chunks) and — the spec's additional edge case — auto-cancels
  `:active` catalog plans whose product was archived/taken down.
  """

  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  import Mox

  require Ash.Query

  alias Emakola.Catalog.Variant
  alias Emakola.Orders.{SusuLifecycle, SusuPlan}
  alias Emakola.Payments.{GatewayMock, Payment, SusuRefunds}
  alias Emakola.Payments.Gateways
  alias Emakola.Payments.Workers.SusuExpiryWorker

  setup :verify_on_exit!

  setup do
    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    store = create_store!()
    %{store: store}
  end

  # -- Helpers -----------------------------------------------------------

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)
  defp past_deadline(hours \\ 1), do: DateTime.add(DateTime.utc_now(), -hours, :hour)

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
      delivery_address: %{"name" => "Ama Mensah", "phone" => "0201234567", "address" => "Accra"}
    })
    |> Ash.update!(authorize?: false)
  end

  defp force_deadline!(plan, deadline) do
    plan
    |> Ash.Changeset.for_update(:update_delivery, %{delivery_address: plan.delivery_address})
    |> Ash.Changeset.force_change_attribute(:deadline, deadline)
    |> Ash.update!(authorize?: false)
  end

  # A :success payment counted toward `plan` — the same shape
  # `SusuCompletionTest.create_contribution!/4` builds.
  defp create_contribution!(store, plan, amount, opts \\ []) do
    payment =
      create_payment!(
        store,
        Keyword.merge(
          [
            susu_plan_id: plan.id,
            amount: amount,
            payout_held: true,
            payout_hold_reason: "susu_plan",
            metadata: %{"susu_counted" => true}
          ],
          opts
        )
      )

    payment
    |> Ash.Changeset.for_update(:mark_success, %{gateway_response: %{}})
    |> Ash.update!(authorize?: false)
  end

  # Builds an :active custom-type plan (no catalog stock to worry about)
  # with counted contributions summing to less than total_amount (stays
  # :active, never auto-completes).
  defp active_plan_with_contributions!(store, amounts) do
    customer = create_customer!(store)
    total = Enum.sum(amounts) + 5_000
    plan = create_plan!(store, %{type: :custom, title: "Kente cloth", total_amount: total})
    plan = activate!(plan, customer)

    Enum.reduce(amounts, plan, fn amount, plan ->
      create_contribution!(store, plan, amount)

      plan
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: amount})
      |> Ash.update!(authorize?: false)
    end)
  end

  defp active_catalog_plan!(store, variant, amounts) do
    customer = create_customer!(store)
    total = Enum.sum(amounts) + 5_000

    plan =
      create_plan!(store, %{
        type: :catalog,
        variant_id: variant.id,
        quantity: 2,
        total_amount: total
      })

    :ok = Emakola.Orders.SusuStock.reserve(plan)
    plan = activate!(plan, customer)

    Enum.reduce(amounts, plan, fn amount, plan ->
      create_contribution!(store, plan, amount)

      plan
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: amount})
      |> Ash.update!(authorize?: false)
    end)
  end

  defp reload_plan(plan), do: Ash.get!(SusuPlan, plan.id, authorize?: false)
  defp reload_payment(payment), do: Ash.get!(Payment, payment.id, authorize?: false)
  defp reload_variant(variant), do: Ash.get!(Variant, variant.id, authorize?: false)

  defp payments_for(plan) do
    Payment
    |> Ash.Query.filter(susu_plan_id == ^plan.id)
    |> Ash.read!(authorize?: false)
  end

  defp expect_refund(n) do
    expect(GatewayMock, :process_refund, n, fn reference, amount ->
      {:ok, %{reference: reference, amount: amount, status: :processed}}
    end)
  end

  # ── SusuRefunds.refund_all_contributions/1 ──────────────────────────

  describe "refund_all_contributions/1 — claim discipline" do
    test "asks the gateway exactly once per counted contribution", %{store: store} do
      plan = active_plan_with_contributions!(store, [3_000, 2_000])
      expect_refund(2)

      assert :ok = SusuRefunds.refund_all_contributions(plan)
    end

    test "a re-run does not re-ask the gateway for an already-claimed payment", %{store: store} do
      plan = active_plan_with_contributions!(store, [3_000])
      expect_refund(1)

      assert :ok = SusuRefunds.refund_all_contributions(plan)
      assert :ok = SusuRefunds.refund_all_contributions(plan)

      [payment] = payments_for(plan)
      assert reload_payment(payment).metadata["susu_refund_claimed"] == true
    end

    test "gateway {:error, _} releases the claim so a re-run retries", %{store: store} do
      plan = active_plan_with_contributions!(store, [4_000])

      expect(GatewayMock, :process_refund, fn _reference, _amount ->
        {:error, {:paystack_error, "insufficient balance"}}
      end)

      assert :ok = SusuRefunds.refund_all_contributions(plan)

      [payment] = payments_for(plan)
      assert reload_payment(payment).metadata["susu_refund_claimed"] == false

      expect_refund(1)
      assert :ok = SusuRefunds.refund_all_contributions(plan)

      assert reload_payment(payment).metadata["susu_refund_claimed"] == true
    end

    test "skips a payment already marked :refunded", %{store: store} do
      plan = active_plan_with_contributions!(store, [4_000])
      [payment] = payments_for(plan)

      payment
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: payment.amount})
      |> Ash.update!(authorize?: false)

      # No `expect_refund` set — Mox raises on any unexpected call, so this
      # only stays green if the gateway is never asked.
      assert :ok = SusuRefunds.refund_all_contributions(plan)
    end

    test "a Hubtel-charged contribution surfaces :not_supported without crashing the sweep", %{
      store: store
    } do
      customer = create_customer!(store)
      plan = create_plan!(store, %{type: :custom, title: "Sandals", total_amount: 9_000})
      plan = activate!(plan, customer)

      payment =
        create_contribution!(store, plan, 4_000, gateway: :hubtel, gateway_reference: "HUB-1")

      plan =
        plan
        |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 4_000})
        |> Ash.update!(authorize?: false)

      # Hubtel's real gateway module — always {:error, :not_supported}, no
      # HTTP call, no Mox needed.
      assert Gateways.Hubtel.process_refund("HUB-1", 4_000) == {:error, :not_supported}

      assert :ok = SusuRefunds.refund_all_contributions(plan)

      reloaded = reload_payment(payment)
      assert reloaded.metadata["susu_refund_claimed"] == false
      assert reloaded.metadata["refund_note"] =~ "refund this payment manually"
    end
  end

  # ── SusuLifecycle — convergence ──────────────────────────────────────

  describe "SusuLifecycle.cancel/2 — convergence across actors" do
    test "buyer and merchant cancel produce the identical end state", %{store: store} do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan_a = active_catalog_plan!(store, variant, [3_000])
      plan_b = active_catalog_plan!(store, variant, [3_000])

      before_stock = reload_variant(variant).stock_quantity

      expect_refund(2)

      assert {:ok, cancelled_a} = SusuLifecycle.cancel(plan_a, :buyer)
      assert {:ok, cancelled_b} = SusuLifecycle.cancel(plan_b, :merchant)

      assert cancelled_a.status == :cancelled
      assert cancelled_b.status == :cancelled

      # Both plans reserved `quantity: 2`; both released it back.
      assert reload_variant(variant).stock_quantity == before_stock + 4

      Enum.each(payments_for(plan_a) ++ payments_for(plan_b), fn payment ->
        assert reload_payment(payment).metadata["susu_refund_claimed"] == true
      end)
    end
  end

  describe "SusuLifecycle — zero-contribution plans" do
    test "cancelling a never-activated (:pending) plan is a clean transition", %{store: store} do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)

      plan =
        create_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 2,
          total_amount: 10_000
        })

      before_stock = reload_variant(variant).stock_quantity

      # No `expect_refund` — a call here would fail the test via Mox.
      assert {:ok, cancelled} = SusuLifecycle.cancel(plan, :merchant)

      assert cancelled.status == :cancelled
      assert reload_variant(variant).stock_quantity == before_stock
      assert payments_for(plan) == []
    end
  end

  describe "SusuLifecycle — stock release idempotency" do
    test "releasing an already-released plan's stock a second time does not double-credit", %{
      store: store
    } do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)
      plan = active_catalog_plan!(store, variant, [3_000])

      before_stock = reload_variant(variant).stock_quantity
      expect_refund(1)

      assert {:ok, cancelled} = SusuLifecycle.cancel(plan, :merchant)
      once = reload_variant(variant).stock_quantity
      assert once == before_stock + 2

      # Calling release directly again (the underlying idempotency
      # `SusuLifecycle.converge/1` relies on) must not credit twice.
      :ok = Emakola.Orders.SusuStock.release(reload_plan(cancelled))
      assert reload_variant(variant).stock_quantity == once
    end
  end

  # ── SusuExpiryWorker — deadline sweep ────────────────────────────────

  describe "SusuExpiryWorker — deadline expiry" do
    test "expires a due :active plan: transitions, releases stock, refunds contributions", %{
      store: store
    } do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)
      plan = active_catalog_plan!(store, variant, [3_000])
      plan = force_deadline!(plan, past_deadline())

      before_stock = reload_variant(variant).stock_quantity
      expect_refund(1)

      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})

      assert reload_plan(plan).status == :expired
      assert reload_variant(variant).stock_quantity == before_stock + 2

      [payment] = payments_for(plan)
      assert reload_payment(payment).metadata["susu_refund_claimed"] == true
    end

    test "leaves a plan with an in-flight :pending chunk alone (re-swept next run)", %{
      store: store
    } do
      plan = active_plan_with_contributions!(store, [3_000])
      plan = force_deadline!(plan, past_deadline())

      _pending = create_payment!(store, %{susu_plan_id: plan.id, amount: 2_000})

      # No `expect_refund` set: the plan must not be touched this run.
      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})
      assert reload_plan(plan).status == :active

      # Once the in-flight chunk resolves (fails, say), the next run
      # expires it — proving "re-swept next run".
      pending = payments_for(plan) |> Enum.find(&(&1.status == :pending))

      pending
      |> Ash.Changeset.for_update(:mark_failed, %{gateway_response: %{}})
      |> Ash.update!(authorize?: false)

      expect_refund(1)
      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})
      assert reload_plan(plan).status == :expired
    end

    test "a plan with TWO in-flight :pending chunks (concurrent-initiation race) does not crash the sweep",
         %{store: store} do
      # SusuChunks.initiate_chunk/4's own moduledoc documents this exact
      # race: two genuinely concurrent initiations can both pass the
      # one-pending-chunk guard and both reach the gateway, leaving TWO
      # :pending payments for the same plan. `in_flight_chunk?/1` must
      # tolerate this (not raise), or one racy plan takes down the whole
      # sweep run — including the takedown duty below, never reached.
      racy_plan = active_plan_with_contributions!(store, [3_000])
      racy_plan = force_deadline!(racy_plan, past_deadline())
      create_payment!(store, %{susu_plan_id: racy_plan.id, amount: 1_000})
      create_payment!(store, %{susu_plan_id: racy_plan.id, amount: 1_000})

      other_due_plan = active_plan_with_contributions!(store, [4_000])
      other_due_plan = force_deadline!(other_due_plan, past_deadline())

      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)
      taken_down_plan = active_catalog_plan!(store, variant, [3_000])
      Emakola.Catalog.archive_product!(product, authorize?: false)

      # Only `other_due_plan` and `taken_down_plan` get refunded this run —
      # `racy_plan` is skipped, so its contribution is untouched.
      expect_refund(2)

      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})

      assert reload_plan(racy_plan).status == :active
      assert reload_plan(other_due_plan).status == :expired
      assert reload_plan(taken_down_plan).status == :cancelled
    end

    test "idempotent re-run: running the sweep twice refunds once and does not crash", %{
      store: store
    } do
      plan = active_plan_with_contributions!(store, [3_000])
      plan = force_deadline!(plan, past_deadline())

      expect_refund(1)

      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})
      assert reload_plan(plan).status == :expired

      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})
      assert reload_plan(plan).status == :expired
    end
  end

  # ── SusuExpiryWorker — takedown auto-cancel (additional sweep duty) ──

  describe "SusuExpiryWorker — product takedown auto-cancel" do
    test "auto-cancels an :active catalog plan whose product was archived", %{store: store} do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)
      plan = active_catalog_plan!(store, variant, [3_000])

      Emakola.Catalog.archive_product!(product, authorize?: false)

      before_stock = reload_variant(variant).stock_quantity
      expect_refund(1)

      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})

      assert reload_plan(plan).status == :cancelled
      assert reload_variant(variant).stock_quantity == before_stock + 2
    end

    test "auto-cancels an :active catalog plan whose product was moderation-taken-down", %{
      store: store
    } do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)
      plan = active_catalog_plan!(store, variant, [3_000])

      Emakola.Catalog.take_down_product!(product, %{reason: "counterfeit"}, authorize?: false)

      expect_refund(1)

      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})
      assert reload_plan(plan).status == :cancelled
    end

    test "leaves an :active catalog plan alone while its product stays available", %{
      store: store
    } do
      product = create_product!(store)
      variant = create_variant!(product, store, stock_quantity: 10, track_inventory: true)
      plan = active_catalog_plan!(store, variant, [3_000])

      # No `expect_refund` — untouched, so no gateway call.
      assert :ok = SusuExpiryWorker.perform(%Oban.Job{})
      assert reload_plan(plan).status == :active
    end
  end
end
