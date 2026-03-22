defmodule Emakola.Notifications.Workers.OrderNotificationWorkerEmailTest do
  @moduledoc """
  Tests for email delivery integration in OrderNotificationWorker.
  Tagged :pending — requires updated notification worker with email integration.
  """
  use Emakola.DataCase, async: true

  @moduletag :pending

  import Swoosh.TestAssertions
  import Emakola.Factory

  alias Emakola.Notifications.Workers.OrderNotificationWorker

  describe "email integration in perform/1" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      %{store: store}
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
