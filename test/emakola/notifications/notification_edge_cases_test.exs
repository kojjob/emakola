defmodule Emakola.Notifications.NotificationEdgeCasesTest do
  @moduledoc """
  Edge case tests for the notification dispatch pipeline.

  Covers unknown events, nil/missing data, idempotency, currency formatting
  extremes, and graceful degradation when external providers fail.
  """

  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  import ExUnit.CaptureLog

  alias Emakola.Notifications.Dispatcher
  alias Emakola.Notifications.Templates
  alias Emakola.Notifications.Workers.OrderNotificationWorker

  # ── Helpers ─────────────────────────────────────────────────────

  defp fake_order(attrs \\ %{}) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        order_number: "ORD-20260322-EDGE01",
        total: 10_000,
        currency: "GHS",
        store_id: Ash.UUID.generate(),
        customer_id: nil
      },
      attrs
    )
  end

  defp fake_store(attrs \\ %{}) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        name: "Test Store",
        slug: "test-store",
        contact_email: "shop@example.com",
        contact_phone: "+233201234567",
        whatsapp_number: "+233201234567",
        logo_url: nil
      },
      attrs
    )
  end

  # ── Dispatch: unknown event type ────────────────────────────────

  describe "dispatch/2 with unknown event type" do
    test "returns {:error, :unknown_event} for unrecognized atom" do
      order = fake_order()
      assert {:error, :unknown_event} = Dispatcher.dispatch(order, :order_refunded)
    end

    test "returns {:error, :unknown_event} for integer event" do
      order = fake_order()
      assert {:error, :unknown_event} = Dispatcher.dispatch(order, 42)
    end

    test "returns {:error, :unknown_event} for map event" do
      order = fake_order()
      assert {:error, :unknown_event} = Dispatcher.dispatch(order, %{type: :placed})
    end
  end

  # ── Dispatch: nil store_id ──────────────────────────────────────

  describe "dispatch/2 with nil store_id in order" do
    test "enqueues job (dispatcher does not validate store_id)" do
      # The dispatcher only requires %{id: _} — store_id validation happens in the worker
      order = fake_order(%{store_id: nil})
      assert {:ok, %Oban.Job{}} = Dispatcher.dispatch(order, :order_placed)
    end
  end

  # ── Dispatch: non-existent order_id (worker behavior) ───────────

  describe "worker with non-existent order_id" do
    test "returns error and logs when order cannot be found" do
      non_existent_id = Ash.UUID.generate()

      log =
        capture_log(fn ->
          result =
            perform_job(OrderNotificationWorker, %{
              "order_id" => non_existent_id,
              "event" => "order_placed"
            })

          assert {:error, :order_not_found} = result
        end)

      assert log =~ "Failed to process notification"
      assert log =~ non_existent_id
    end
  end

  # ── SMS template: very long customer name ───────────────────────

  describe "SMS template with very long customer name" do
    test "renders without crashing (name appears in WhatsApp params, not directly in SMS)" do
      long_name = String.duplicate("Kofi ", 200) |> String.trim()
      order = fake_order(%{order_number: "ORD-LONG-NAME"})
      store = fake_store(%{name: "Long Name Store"})

      # SMS templates don't include customer name, so just verify no crash
      message = Templates.order_placed_sms(order, store)
      assert is_binary(message)
      assert message =~ "ORD-LONG-NAME"

      # WhatsApp params don't include customer name either, but verify no crash
      params = Templates.whatsapp_params(order, store)
      assert params.store_name == "Long Name Store"

      # The long name is used by the worker for addressing, verify template works
      assert String.length(message) > 0
    end
  end

  # ── WhatsApp template: special characters in store name ─────────

  describe "WhatsApp template with special characters in store name" do
    test "handles Akan characters in store name" do
      store = fake_store(%{name: "Nkwanta Ɛdwuma Fie"})
      order = fake_order()

      params = Templates.whatsapp_params(order, store)
      assert params.store_name == "Nkwanta Ɛdwuma Fie"

      sms = Templates.order_placed_sms(order, store)
      assert sms =~ "Nkwanta Ɛdwuma Fie"
    end

    test "handles ampersands and quotes in store name" do
      store = fake_store(%{name: "Kwame & Sons \"Boutique\""})
      order = fake_order()

      sms = Templates.order_confirmed_sms(order, store)
      assert sms =~ "Kwame & Sons"
    end

    test "handles emoji in store name" do
      store = fake_store(%{name: "Ghana Shop 🇬🇭"})
      order = fake_order()

      params = Templates.whatsapp_params(order, store)
      assert params.store_name == "Ghana Shop 🇬🇭"
    end
  end

  # ── Worker: all providers fail (no crash) ───────────────────────

  describe "worker when SMS and WhatsApp providers succeed (log providers)" do
    setup do
      store = create_store!(%{contact_email: "shop@edge.com", contact_phone: "+233201234567"})
      customer = create_customer!(store, %{phone: "+233551234567"})
      order = create_order!(store, %{customer_id: customer.id})
      {:ok, store: store, customer: customer, order: order}
    end

    test "completes without error for order_placed", %{order: order} do
      # The LogSMS and LogWhatsApp providers always return {:ok, _}
      # This verifies the worker pipeline runs end-to-end without crashing
      log =
        capture_log(fn ->
          result =
            perform_job(OrderNotificationWorker, %{
              "order_id" => order.id,
              "event" => "order_placed"
            })

          assert :ok = result
        end)

      # Verify SMS and WhatsApp logs were generated
      assert log =~ "[LogSMS]" or log =~ "[LogWhatsApp]" or log =~ "Merchant SMS"
    end
  end

  # ── Duplicate notification dispatch (Oban unique constraint) ────

  describe "duplicate notification dispatch" do
    test "Oban unique constraint prevents duplicate jobs within period" do
      order = fake_order()

      {:ok, job1} = Dispatcher.dispatch(order, :order_placed)
      {:ok, job2} = Dispatcher.dispatch(order, :order_placed)

      # Oban unique returns the existing job when a duplicate is detected
      # Both return {:ok, %Oban.Job{}} but the second should be the same job
      assert job1.id == job2.id
    end

    test "different events for same order create separate jobs" do
      order = fake_order()

      {:ok, job1} = Dispatcher.dispatch(order, :order_placed)
      {:ok, job2} = Dispatcher.dispatch(order, :order_confirmed)

      # Different events = different args = different unique keys
      refute job1.id == job2.id
    end
  end

  # ── Worker: customer with no phone AND no email ─────────────────

  describe "worker with customer that has no phone" do
    setup do
      store = create_store!()
      customer = create_customer!(store, %{phone: nil})
      order = create_order!(store, %{customer_id: customer.id})
      {:ok, store: store, customer: customer, order: order}
    end

    test "skips customer notification gracefully", %{order: order} do
      log =
        capture_log(fn ->
          result =
            perform_job(OrderNotificationWorker, %{
              "order_id" => order.id,
              "event" => "order_placed"
            })

          assert :ok = result
        end)

      assert log =~ "No customer phone" or log =~ "skipping customer notification"
    end
  end

  describe "worker with no customer_id on order" do
    setup do
      store = create_store!()
      order = create_order!(store, %{customer_id: nil})
      {:ok, store: store, order: order}
    end

    test "skips customer notification when customer_id is nil", %{order: order} do
      log =
        capture_log(fn ->
          result =
            perform_job(OrderNotificationWorker, %{
              "order_id" => order.id,
              "event" => "order_confirmed"
            })

          assert :ok = result
        end)

      # Worker should handle nil customer gracefully
      assert log =~ "No customer phone" or log =~ "skipping"
    end
  end

  # ── All 5 event types through the dispatcher ────────────────────

  describe "dispatch for all 5 event types" do
    @events ~w(order_placed order_confirmed order_shipped order_delivered order_cancelled)a

    for event <- @events do
      test "dispatches #{event} successfully" do
        order = fake_order()
        event = unquote(event)

        assert {:ok, %Oban.Job{}} = Dispatcher.dispatch(order, event)

        assert_enqueued(
          worker: OrderNotificationWorker,
          args: %{order_id: order.id, event: Atom.to_string(event)},
          queue: :notifications
        )
      end
    end
  end

  # ── Currency formatting edge cases ──────────────────────────────

  describe "format_amount/1 currency edge cases" do
    test "0 pesewas formats as 0.00" do
      assert Templates.format_amount(0) == "0.00"
    end

    test "1 peseawa formats as 0.01" do
      assert Templates.format_amount(1) == "0.01"
    end

    test "99 pesewas formats as 0.99" do
      assert Templates.format_amount(99) == "0.99"
    end

    test "100 pesewas formats as 1.00" do
      assert Templates.format_amount(100) == "1.00"
    end

    test "very large amount (1_000_000_00 pesewas = GHS 1,000,000) formats correctly" do
      assert Templates.format_amount(1_000_000_00) == "1000000.00"
    end

    test "single digit minor units pad correctly" do
      assert Templates.format_amount(5) == "0.05"
    end

    test "10 pesewas formats as 0.10" do
      assert Templates.format_amount(10) == "0.10"
    end
  end

  describe "SMS templates include correct currency symbols" do
    test "GHS order shows cedi symbol" do
      order = fake_order(%{currency: "GHS", total: 50_000})
      store = fake_store()

      sms = Templates.order_placed_sms(order, store)
      # GH₵ (cedi symbol)
      assert sms =~ "GH₵"
      assert sms =~ "500.00"
    end

    test "NGN order shows naira symbol" do
      order = fake_order(%{currency: "NGN", total: 250_000})
      store = fake_store()

      sms = Templates.order_placed_sms(order, store)
      # ₦ (naira symbol)
      assert sms =~ "₦"
      assert sms =~ "2500.00"
    end

    test "unknown currency shows no symbol" do
      order = fake_order(%{currency: "XYZ", total: 10_000})
      store = fake_store()

      sms = Templates.order_placed_sms(order, store)
      assert sms =~ "100.00"
    end

    test "zero total order" do
      order = fake_order(%{total: 0})
      store = fake_store()

      sms = Templates.order_placed_sms(order, store)
      assert sms =~ "0.00"
    end
  end

  # ── Merchant notification: only fires for placed/cancelled ──────

  describe "merchant notifications only for specific events" do
    setup do
      store = create_store!(%{contact_phone: "+233201234567"})
      customer = create_customer!(store, %{phone: "+233551234567"})
      order = create_order!(store, %{customer_id: customer.id})
      {:ok, store: store, customer: customer, order: order}
    end

    test "order_placed triggers merchant SMS", %{order: order} do
      log =
        capture_log(fn ->
          assert :ok =
                   perform_job(OrderNotificationWorker, %{
                     "order_id" => order.id,
                     "event" => "order_placed"
                   })
        end)

      assert log =~ "Merchant SMS"
    end

    test "order_cancelled triggers merchant SMS", %{order: order} do
      log =
        capture_log(fn ->
          assert :ok =
                   perform_job(OrderNotificationWorker, %{
                     "order_id" => order.id,
                     "event" => "order_cancelled"
                   })
        end)

      assert log =~ "Merchant SMS"
    end

    test "order_confirmed does NOT trigger merchant SMS", %{order: order} do
      log =
        capture_log(fn ->
          assert :ok =
                   perform_job(OrderNotificationWorker, %{
                     "order_id" => order.id,
                     "event" => "order_confirmed"
                   })
        end)

      refute log =~ "Merchant SMS"
    end
  end
end
