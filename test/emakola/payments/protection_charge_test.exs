defmodule Emakola.Payments.ProtectionChargeTest do
  @moduledoc """
  TC-2 Buyer Protection — the charge-time predicate (`Protection.applies?/2`)
  and idempotent webhook-confirm hold creation (`ProtectionHolds.ensure_hold/1`),
  wired into both webhook confirm sites (Paystack + Hubtel).

  `OrderSettlement.prepare/2`'s hold-mode integration is covered in
  order_settlement_test.exs (it already owns every other `prepare/2` case).
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  require Ash.Query
  import Emakola.Factory
  import ExUnit.CaptureLog

  alias Emakola.Payments.{HubtelWebhook, Protection, ProtectionHold, ProtectionHolds}
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  # -- Protection.applies?/2 — pure predicate ------------------------------

  describe "Protection.applies?/2" do
    test "a pay link's protected: true wins regardless of the store setting" do
      assert Protection.applies?(%{buyer_protection_enabled: false}, %{protected: true})
    end

    test "a pay link's protected: false wins regardless of the store setting" do
      refute Protection.applies?(%{buyer_protection_enabled: true}, %{protected: false})
    end

    test "a legacy pay link with protected: nil is treated as unprotected" do
      refute Protection.applies?(%{buyer_protection_enabled: true}, %{protected: nil})
    end

    test "no pay link falls back to the store's buyer_protection_enabled" do
      assert Protection.applies?(%{buyer_protection_enabled: true}, nil)
      refute Protection.applies?(%{buyer_protection_enabled: false}, nil)
    end
  end

  # -- ProtectionHolds.ensure_hold/1 ----------------------------------------

  describe "ProtectionHolds.ensure_hold/1" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      order = create_order!(store, %{total: 25_000})
      %{store: store, order: order}
    end

    test "creates exactly one hold with fee + net == amount for a held payment", %{
      store: store,
      order: order
    } do
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: 25_000,
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })

      assert :ok = ProtectionHolds.ensure_hold(payment)

      {:ok, hold} =
        Emakola.Payments.get_protection_hold_by_payment(payment.id,
          tenant: store.id,
          authorize?: false
        )

      assert hold.amount == 25_000
      assert hold.fee + hold.net == hold.amount
      assert hold.status == :held
      assert hold.order_id == order.id
    end

    test "re-running for the same payment creates no second hold (idempotent)", %{
      store: store,
      order: order
    } do
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: 25_000,
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })

      assert :ok = ProtectionHolds.ensure_hold(payment)

      log =
        capture_log(fn ->
          assert :ok = ProtectionHolds.ensure_hold(payment)
        end)

      # Async-suite capture_log sees concurrent tests' output; assert only
      # that OUR payment's id was not logged, not that the world was silent.
      # A benign idempotent retry (unique_payment identity violation) must
      # stay silent — Logger.error here would mask real failures in prod
      # alerting.
      refute log =~ payment.id

      holds =
        ProtectionHold
        |> Ash.Query.filter(payment_id == ^payment.id)
        |> Ash.Query.set_tenant(store.id)
        |> Ash.read!(authorize?: false)

      assert length(holds) == 1
    end

    test "a genuinely invalid create (not a unique violation) still logs an error", %{
      store: store
    } do
      # order_id is required on ProtectionHold — a payment with no order_id
      # (nilable on Payment) forces a real Ash validation failure distinct
      # from the benign unique_payment retry, proving the rescue still
      # alerts on a genuine failure.
      payment =
        create_payment!(store, %{
          amount: 25_000,
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })

      assert payment.order_id == nil

      log =
        capture_log(fn ->
          assert :ok = ProtectionHolds.ensure_hold(payment)
        end)

      assert log =~ payment.id
      assert log =~ "[protection_holds] ensure_hold failed"

      assert {:ok, nil} =
               Emakola.Payments.get_protection_hold_by_payment(payment.id,
                 tenant: store.id,
                 authorize?: false,
                 not_found_error?: false
               )
    end

    test "a payment not under a buyer_protection hold creates no hold", %{
      store: store,
      order: order
    } do
      payment = create_payment!(store, %{order_id: order.id, amount: 25_000})

      assert :ok = ProtectionHolds.ensure_hold(payment)

      assert {:ok, nil} =
               Emakola.Payments.get_protection_hold_by_payment(payment.id,
                 tenant: store.id,
                 authorize?: false,
                 not_found_error?: false
               )
    end

    test "a payment held for a different reason (e.g. group_buy_escrow) creates no hold", %{
      store: store,
      order: order
    } do
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: 25_000,
          payout_held: true,
          payout_hold_reason: "group_buy_escrow"
        })

      assert :ok = ProtectionHolds.ensure_hold(payment)

      assert {:ok, nil} =
               Emakola.Payments.get_protection_hold_by_payment(payment.id,
                 tenant: store.id,
                 authorize?: false,
                 not_found_error?: false
               )
    end

    # ── Task 10: :protection_held dispatch ────────────────────────

    test "dispatches :protection_held to the buyer after successfully creating the hold", %{
      store: store,
      order: order
    } do
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: 25_000,
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })

      assert :ok = ProtectionHolds.ensure_hold(payment)

      assert_enqueued(
        worker: Emakola.Notifications.Workers.OrderNotificationWorker,
        args: %{order_id: order.id, event: "protection_held"},
        queue: :notifications
      )
    end

    test "does not dispatch again on an idempotent retry no-op", %{store: store, order: order} do
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: 25_000,
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })

      assert :ok = ProtectionHolds.ensure_hold(payment)
      assert :ok = ProtectionHolds.ensure_hold(payment)

      jobs =
        all_enqueued(
          worker: Emakola.Notifications.Workers.OrderNotificationWorker,
          args: %{order_id: order.id, event: "protection_held"}
        )

      assert length(jobs) == 1
    end
  end

  # -- Webhook confirm wiring ------------------------------------------------

  describe "webhook confirm wiring — Paystack" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      order = create_order!(store, %{total: 12_000})
      %{store: store, order: order}
    end

    test "charge.success on a held payment creates exactly one hold, idempotently", %{
      store: store,
      order: order
    } do
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: 12_000,
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })

      event = %{
        "event" => "charge.success",
        "data" => %{
          "reference" => payment.gateway_reference,
          "amount" => 12_000,
          "currency" => "GHS",
          "status" => "success"
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert :ok = perform_job(PaystackWebhookHandler, event)

      holds =
        ProtectionHold
        |> Ash.Query.filter(payment_id == ^payment.id)
        |> Ash.Query.set_tenant(store.id)
        |> Ash.read!(authorize?: false)

      assert [hold] = holds
      assert hold.fee + hold.net == hold.amount
    end

    test "charge.success on a normal (unheld) payment creates no hold", %{
      store: store,
      order: order
    } do
      payment = create_payment!(store, %{order_id: order.id, amount: 12_000})

      event = %{
        "event" => "charge.success",
        "data" => %{
          "reference" => payment.gateway_reference,
          "amount" => 12_000,
          "currency" => "GHS",
          "status" => "success"
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)

      assert {:ok, nil} =
               Emakola.Payments.get_protection_hold_by_payment(payment.id,
                 tenant: store.id,
                 authorize?: false,
                 not_found_error?: false
               )
    end
  end

  describe "webhook confirm wiring — Hubtel" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      order = create_order!(store, %{total: 8_000})
      %{store: store, order: order}
    end

    test "ResponseCode 0000 on a held payment creates exactly one hold, idempotently", %{
      store: store,
      order: order
    } do
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: 8_000,
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })

      event = %{
        "ResponseCode" => "0000",
        "Data" => %{"ClientReference" => payment.gateway_reference, "Amount" => 80.0}
      }

      assert :ok = HubtelWebhook.handle_event(event)
      assert :ok = HubtelWebhook.handle_event(event)

      holds =
        ProtectionHold
        |> Ash.Query.filter(payment_id == ^payment.id)
        |> Ash.Query.set_tenant(store.id)
        |> Ash.read!(authorize?: false)

      assert [hold] = holds
      assert hold.fee + hold.net == hold.amount
    end

    test "ResponseCode 0000 on a normal (unheld) payment creates no hold", %{
      store: store,
      order: order
    } do
      payment = create_payment!(store, %{order_id: order.id, amount: 8_000})

      event = %{
        "ResponseCode" => "0000",
        "Data" => %{"ClientReference" => payment.gateway_reference, "Amount" => 80.0}
      }

      assert :ok = HubtelWebhook.handle_event(event)

      assert {:ok, nil} =
               Emakola.Payments.get_protection_hold_by_payment(payment.id,
                 tenant: store.id,
                 authorize?: false,
                 not_found_error?: false
               )
    end
  end
end
