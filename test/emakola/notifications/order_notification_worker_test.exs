defmodule Emakola.Notifications.Workers.OrderNotificationWorkerTest do
  use Emakola.DataCase, async: false

  import Mox

  alias Emakola.Notifications.Workers.OrderNotificationWorker
  alias Emakola.Factory
  alias EmakolaWeb.TrackingTokens

  setup :verify_on_exit!

  # ── Helpers ────────────────────────────────────────────────────

  @merchant_phone "+233301234567"

  defp create_order_with_customer(phone \\ "+233201234567") do
    {_merchant, store} = Factory.create_merchant_with_store!()

    store =
      store
      |> Ash.Changeset.for_update(:update_settings, %{contact_phone: @merchant_phone})
      |> Ash.update!(authorize?: false)

    customer =
      Factory.create_customer!(store, %{
        phone: phone,
        name: "Kwame Mensah"
      })

    order =
      Factory.create_order!(store, %{
        customer_id: customer.id,
        total: 25_000,
        currency: "GHS"
      })

    {order, customer, store}
  end

  defp create_order_without_customer do
    {_merchant, store} = Factory.create_merchant_with_store!()

    store =
      store
      |> Ash.Changeset.for_update(:update_settings, %{contact_phone: @merchant_phone})
      |> Ash.update!(authorize?: false)

    order = Factory.create_order!(store, %{total: 10_000, currency: "GHS"})
    {order, store}
  end

  defp perform_job(order_id, event) do
    OrderNotificationWorker.perform(%Oban.Job{
      args: %{"order_id" => order_id, "event" => event}
    })
  end

  # ── order_confirmed ────────────────────────────────────────────

  describe "order_confirmed event" do
    test "sends SMS and WhatsApp to customer" do
      {order, customer, _store} = create_order_with_customer()

      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "confirmed"
        assert message =~ order.order_number
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn to, template, params, _opts ->
        assert to == customer.phone
        assert template == "order_confirmed"
        assert params.order_number == order.order_number
        {:ok, %{provider: :mock, to: to, template: template}}
      end)

      assert :ok == perform_job(order.id, "order_confirmed")
    end
  end

  # ── order_placed ───────────────────────────────────────────────

  describe "order_placed event" do
    test "sends customer SMS/WhatsApp and merchant SMS" do
      {order, customer, _store} = create_order_with_customer()

      # Customer SMS
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "placed"
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      # Customer WhatsApp
      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn to, template, _params, _opts ->
        assert to == customer.phone
        assert template == "order_placed"
        {:ok, %{provider: :mock, to: to, template: template}}
      end)

      # Merchant SMS
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == @merchant_phone
        assert message =~ "New order"
        assert message =~ order.order_number
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(order.id, "order_placed")
    end
  end

  # ── order_shipped ──────────────────────────────────────────────

  describe "order_shipped event" do
    test "sends SMS and WhatsApp to customer, no merchant SMS" do
      {order, customer, _store} = create_order_with_customer()

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "shipped"
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn to, template, _params, _opts ->
        assert to == customer.phone
        assert template == "order_shipped"
        {:ok, %{provider: :mock, to: to, template: template}}
      end)

      assert :ok == perform_job(order.id, "order_shipped")
    end
  end

  # ── TC-2 buyer protection lifecycle events (Task 10) ───────────
  # :protection_held / :protection_delivery_nudge are buyer-only (SMS with
  # a signed tracking link, no WhatsApp — no approved template exists, no
  # merchant SMS). :protection_released / :protection_complaint are
  # merchant-only (SMS, never the customer channel). Every test below uses
  # a customer WITH a phone precisely so a channel-gating bug (buyer SMS
  # firing for a merchant event, or vice versa) surfaces as a Mox
  # unexpected-call failure rather than passing by accident.

  describe "protection_held event" do
    test "sends the buyer an SMS with a signed tracking link — no WhatsApp, no merchant SMS" do
      {order, customer, _store} = create_order_with_customer()

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "held"
        assert message =~ order.order_number
        assert message =~ "?t="

        token = message |> String.split("?t=") |> List.last() |> String.trim()
        assert {:ok, order_id} = TrackingTokens.verify_order_tracking(token)
        assert order_id == order.id

        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      # No WhatsApp expectation set — a call here fails the test (Mox
      # unexpected-call), which is exactly how "WhatsApp is skipped" is
      # proven, matching this file's existing "no merchant SMS" idiom.

      assert :ok == perform_job(order.id, "protection_held")
    end
  end

  describe "protection_delivery_nudge event" do
    test "sends the buyer an SMS with a signed tracking link — no WhatsApp, no merchant SMS" do
      {order, customer, _store} = create_order_with_customer()

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "confirm"
        assert message =~ "5 days"
        assert message =~ order.order_number
        assert message =~ "?t="

        token = message |> String.split("?t=") |> List.last() |> String.trim()
        assert {:ok, order_id} = TrackingTokens.verify_order_tracking(token)
        assert order_id == order.id

        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(order.id, "protection_delivery_nudge")
    end
  end

  describe "protection_released event" do
    test "sends the merchant an SMS — never the customer channel" do
      {order, _customer, _store} = create_order_with_customer()

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == @merchant_phone
        assert message =~ "released"
        assert message =~ order.order_number
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      # No customer SMS/WhatsApp expectation set, even though `customer`
      # has a phone — proves the buyer channel is genuinely skipped, not
      # just unreached because there was nothing to send to.

      assert :ok == perform_job(order.id, "protection_released")
    end
  end

  describe "protection_complaint event" do
    test "sends the merchant an SMS — never the customer channel" do
      {order, _customer, _store} = create_order_with_customer()

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == @merchant_phone
        assert message =~ "complaint"
        assert message =~ order.order_number
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(order.id, "protection_complaint")
    end
  end

  # ── Missing customer phone ────────────────────────────────────

  describe "missing customer phone" do
    test "skips notification when customer has no phone" do
      {order, _customer, _store} = create_order_with_customer(nil)

      # No SMS or WhatsApp expectations — they should not be called
      # But merchant SMS is still sent for order_placed
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, _message, _opts ->
        assert to == @merchant_phone
        {:ok, %{provider: :mock, to: to}}
      end)

      assert :ok == perform_job(order.id, "order_placed")
    end

    test "skips notification when order has no customer" do
      {order, _store} = create_order_without_customer()

      # Merchant SMS is still sent for order_placed
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, _message, _opts ->
        assert to == @merchant_phone
        {:ok, %{provider: :mock, to: to}}
      end)

      assert :ok == perform_job(order.id, "order_placed")
    end
  end

  # ── Non-existent order ─────────────────────────────────────────

  describe "non-existent order" do
    test "returns error for unknown order_id" do
      fake_id = Ash.UUID.generate()
      assert {:error, :order_not_found} == perform_job(fake_id, "order_confirmed")
    end
  end

  # ── Idempotency ────────────────────────────────────────────────

  describe "idempotency" do
    test "can be called multiple times for the same order without error" do
      {order, _customer, _store} = create_order_with_customer()

      # First call
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn _to, _msg, _opts -> {:ok, %{}} end)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _template, _params, _opts -> {:ok, %{}} end)

      assert :ok == perform_job(order.id, "order_confirmed")

      # Second call — same result
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn _to, _msg, _opts -> {:ok, %{}} end)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _template, _params, _opts -> {:ok, %{}} end)

      assert :ok == perform_job(order.id, "order_confirmed")
    end
  end
end
