defmodule Emakola.Payments.PaymentSusuParentTest do
  @moduledoc """
  TC-3 Task 2: `Payment.susu_plan_id` + the exactly-one-parent guard.

  The guard is scoped to `:create` only, and it is mutual-exclusion only
  (not "at least one required") — group-buy escrow and protected-preorder
  deposit payments legitimately create with BOTH `order_id` and
  `susu_plan_id` nil (see `Emakola.Suppliers.GroupBuys.commit/1` and
  `Emakola.Suppliers.ProtectedPreorders.deposit/1`), and dozens of existing
  tests rely on `Factory.create_payment!/2`'s parentless default. Only
  "both set at once" is nonsensical and rejected.

  Completion (Task 5) later stamps `order_id` onto a susu payment via
  `:attach_order` — a separate update action, tested here in isolation.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.Payment

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create_susu_plan!(store, attrs \\ %{}) do
    default = %{
      store_id: store.id,
      type: :custom,
      title: "Fridge",
      total_amount: 200_000,
      deadline: future_deadline()
    }

    Emakola.Orders.SusuPlan
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!(authorize?: false)
  end

  describe "create" do
    test "susu plan parent only succeeds" do
      store = create_store!()
      plan = create_susu_plan!(store)

      assert {:ok, payment} =
               Payment
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 susu_plan_id: plan.id,
                 amount: 5_000,
                 currency: "GHS",
                 gateway: :paystack,
                 gateway_reference: "PAY-susu-#{System.unique_integer([:positive])}"
               })
               |> Ash.create(authorize?: false)

      assert payment.susu_plan_id == plan.id
      assert payment.order_id == nil
    end

    test "order parent only succeeds (existing behavior, byte-identical)" do
      store = create_store!()
      order = create_order!(store)

      assert {:ok, payment} =
               Payment
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 order_id: order.id,
                 amount: 5_000,
                 currency: "GHS",
                 gateway: :paystack,
                 gateway_reference: "PAY-order-#{System.unique_integer([:positive])}"
               })
               |> Ash.create(authorize?: false)

      assert payment.order_id == order.id
      assert payment.susu_plan_id == nil
    end

    test "rejects both order_id and susu_plan_id set" do
      store = create_store!()
      order = create_order!(store)
      plan = create_susu_plan!(store)

      assert {:error, %Ash.Error.Invalid{}} =
               Payment
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 order_id: order.id,
                 susu_plan_id: plan.id,
                 amount: 5_000,
                 currency: "GHS",
                 gateway: :paystack,
                 gateway_reference: "PAY-both-#{System.unique_integer([:positive])}"
               })
               |> Ash.create(authorize?: false)
    end

    test "neither parent set stays legal — the group-buy escrow / protected-preorder deposit pattern" do
      store = create_store!()

      # Pins Factory.create_payment!/2's default (no order_id override),
      # the same shape group_buys.ex and protected_preorders.ex create in
      # production, and the ~40 existing tests across the suite that call
      # it bare.
      payment = create_payment!(store)

      assert payment.order_id == nil
      assert payment.susu_plan_id == nil
    end
  end

  describe ":attach_order" do
    test "stamps order_id once onto a susu-plan payment" do
      store = create_store!()
      plan = create_susu_plan!(store)
      order = create_order!(store)

      payment =
        Payment
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          susu_plan_id: plan.id,
          amount: 5_000,
          currency: "GHS",
          gateway: :paystack,
          gateway_reference: "PAY-attach-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!(authorize?: false)

      assert {:ok, attached} =
               payment
               |> Ash.Changeset.for_update(:attach_order, %{order_id: order.id})
               |> Ash.update(authorize?: false)

      assert attached.order_id == order.id
      assert attached.susu_plan_id == plan.id
    end

    test "refuses to re-stamp an already-attached payment" do
      store = create_store!()
      plan = create_susu_plan!(store)
      order = create_order!(store)
      other_order = create_order!(store)

      payment =
        Payment
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          susu_plan_id: plan.id,
          amount: 5_000,
          currency: "GHS",
          gateway: :paystack,
          gateway_reference: "PAY-restamp-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!(authorize?: false)
        |> Ash.Changeset.for_update(:attach_order, %{order_id: order.id})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               payment
               |> Ash.Changeset.for_update(:attach_order, %{order_id: other_order.id})
               |> Ash.update(authorize?: false)
    end

    test "refuses when the payment has no susu_plan_id (an ordinary order payment)" do
      store = create_store!()
      order = create_order!(store)
      other_order = create_order!(store)

      payment = create_payment!(store, %{order_id: order.id})

      assert {:error, %Ash.Error.Invalid{}} =
               payment
               |> Ash.Changeset.for_update(:attach_order, %{order_id: other_order.id})
               |> Ash.update(authorize?: false)
    end
  end

  describe ":mark_buyer_protection_hold" do
    defp susu_held_payment!(store, plan, attrs \\ %{}) do
      default = %{
        store_id: store.id,
        susu_plan_id: plan.id,
        amount: 5_000,
        currency: "GHS",
        gateway: :paystack,
        gateway_reference: "PAY-mbph-#{System.unique_integer([:positive])}",
        payout_held: true,
        payout_hold_reason: "susu_plan"
      }

      Payment
      |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
      |> Ash.create!(authorize?: false)
    end

    test "converts a susu_plan-held payment's hold to buyer_protection" do
      store = create_store!()
      plan = create_susu_plan!(store)
      payment = susu_held_payment!(store, plan)

      assert {:ok, converted} =
               payment
               |> Ash.Changeset.for_update(:mark_buyer_protection_hold, %{})
               |> Ash.update(authorize?: false)

      assert converted.payout_hold_reason == "buyer_protection"
      assert converted.payout_held == true
    end

    test "refuses a payment with no susu_plan_id (an ordinary order-parented payment)" do
      store = create_store!()
      order = create_order!(store)

      payment =
        create_payment!(store, %{
          order_id: order.id,
          payout_held: true,
          payout_hold_reason: "susu_plan"
        })

      assert {:error, %Ash.Error.Invalid{}} =
               payment
               |> Ash.Changeset.for_update(:mark_buyer_protection_hold, %{})
               |> Ash.update(authorize?: false)
    end

    test "refuses a payment already converted to buyer_protection (no double-flip)" do
      store = create_store!()
      plan = create_susu_plan!(store)

      payment =
        store
        |> susu_held_payment!(plan)
        |> Ash.Changeset.for_update(:mark_buyer_protection_hold, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               payment
               |> Ash.Changeset.for_update(:mark_buyer_protection_hold, %{})
               |> Ash.update(authorize?: false)
    end

    test "refuses a payment that is not currently held" do
      store = create_store!()
      plan = create_susu_plan!(store)

      payment = susu_held_payment!(store, plan, %{payout_held: false})

      assert {:error, %Ash.Error.Invalid{}} =
               payment
               |> Ash.Changeset.for_update(:mark_buyer_protection_hold, %{})
               |> Ash.update(authorize?: false)
    end
  end
end
