defmodule Emakola.Notifications.Workers.OrderNotificationWorkerEmailTest do
  @moduledoc """
  Tests for email delivery integration in OrderNotificationWorker.
  Tagged :pending — requires updated notification worker with email integration.
  """
  use Emakola.DataCase, async: false

  import Swoosh.TestAssertions
  import Emakola.Factory
  import Mox

  alias Emakola.Notifications.Workers.OrderNotificationWorker

  setup :verify_on_exit!

  defp drain_mailbox do
    receive do
      {:email, _email} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  describe "email integration in perform/1" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      # Drain any emails sent during setup (e.g., welcome email from merchant creation)
      drain_mailbox()
      %{store: store}
    end

    test "a phone-only customer is notified by SMS and never emailed", %{store: store} do
      # Customer.email became optional so buyers without one can register by
      # phone. This is the shape that could not exist before, so nothing in
      # the suite covered it: the email builders call to_string(customer.email),
      # which would quietly address a message to "" rather than raise.
      customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(
          :register_with_phone,
          %{name: "Ama", phone: "+233201234567"},
          tenant: store.id
        )
        |> Ash.create!(authorize?: false)

      assert is_nil(customer.email)

      order =
        create_order!(store, %{
          customer_id: customer.id,
          total: 50_000,
          subtotal: 48_000,
          currency: "GHS"
        })

      Emakola.SMSProviderMock
      |> stub(:send_sms, fn _to, _message, _opts -> {:ok, %{message_id: "test"}} end)

      # A phone-only customer is reached on their phone — WhatsApp first,
      # which is exactly the ordering Notifications.Reach encodes.
      Emakola.WhatsAppProviderMock
      |> stub(:send_message, fn to, _template, _params, _opts ->
        assert to == "+233201234567"
        {:ok, %{message_id: "wa_1"}}
      end)

      assert :ok =
               OrderNotificationWorker.perform(%Oban.Job{
                 args: %{"order_id" => order.id, "event" => "order_placed"}
               })

      refute_email_sent()
    end

    test "sends order confirmation email when customer has email (no phone)", %{store: store} do
      customer =
        create_customer!(store, %{
          email: "buyer@example.com",
          name: "Test Buyer"
          # No phone — SMS/WhatsApp paths are skipped
        })

      order =
        create_order!(store, %{
          customer_id: customer.id,
          total: 50_000,
          subtotal: 48_000,
          currency: "GHS"
        })

      # Stub merchant SMS mock (order_placed triggers merchant notification)
      Emakola.SMSProviderMock
      |> stub(:send_sms, fn _to, _message, _opts -> {:ok, %{message_id: "test"}} end)

      assert :ok =
               OrderNotificationWorker.perform(%Oban.Job{
                 args: %{"order_id" => order.id, "event" => "order_placed"}
               })

      assert_email_sent(fn email ->
        assert email.subject =~ order.order_number
        assert [{"Test Buyer", "buyer@example.com"}] = email.to
      end)
    end

    test "sends email for order_confirmed event", %{store: store} do
      customer =
        create_customer!(store, %{
          email: "confirmed@example.com",
          name: "Confirmed Buyer"
        })

      order =
        create_order!(store, %{
          customer_id: customer.id,
          total: 30_000,
          subtotal: 28_000,
          currency: "GHS"
        })

      assert :ok =
               OrderNotificationWorker.perform(%Oban.Job{
                 args: %{"order_id" => order.id, "event" => "order_confirmed"}
               })

      assert_email_sent(fn email ->
        assert email.subject =~ "Order Confirmed"
        assert [{"Confirmed Buyer", "confirmed@example.com"}] = email.to
      end)
    end

    test "skips email when order has no customer", %{store: store} do
      order =
        create_order!(store, %{
          customer_id: nil,
          total: 20_000,
          subtotal: 18_000,
          currency: "GHS"
        })

      # Stub merchant SMS mock (order_placed triggers merchant notification)
      Emakola.SMSProviderMock
      |> stub(:send_sms, fn _to, _message, _opts -> {:ok, %{message_id: "test"}} end)

      assert :ok =
               OrderNotificationWorker.perform(%Oban.Job{
                 args: %{"order_id" => order.id, "event" => "order_placed"}
               })

      refute_email_sent()
    end

    test "sends shipping email for order_shipped event", %{store: store} do
      customer =
        create_customer!(store, %{
          email: "shipper@example.com",
          name: "Ship Buyer"
        })

      order =
        create_order!(store, %{
          customer_id: customer.id,
          total: 75_000,
          subtotal: 70_000,
          currency: "GHS"
        })

      assert :ok =
               OrderNotificationWorker.perform(%Oban.Job{
                 args: %{"order_id" => order.id, "event" => "order_shipped"}
               })

      assert_email_sent(fn email ->
        assert email.subject =~ "Has Shipped"
        assert [{"Ship Buyer", "shipper@example.com"}] = email.to
      end)
    end
  end
end
