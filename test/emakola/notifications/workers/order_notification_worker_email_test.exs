defmodule Emakola.Notifications.Workers.OrderNotificationWorkerEmailTest do
  @moduledoc """
  Tests for email delivery integration in OrderNotificationWorker.

  These tests verify that the worker sends email when a customer has an email
  address and skips email when they don't. Customers are created without phone
  numbers to avoid triggering the (not yet implemented) SMS/WhatsApp paths.
  """
  use Emakola.DataCase, async: true

  import Swoosh.TestAssertions
  import Emakola.Factory

  alias Emakola.Notifications.Workers.OrderNotificationWorker

  describe "email integration in perform/1" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      # Drain any emails sent during setup (e.g. welcome email from merchant registration)
      drain_mailbox()
      %{store: store}
    end

    defp drain_mailbox do
      receive do
        {:email, _} -> drain_mailbox()
      after
        0 -> :ok
      end
    end

    test "sends order confirmation email when customer has email", %{store: store} do
      customer =
        create_customer!(store, %{
          email: "buyer@example.com",
          name: "Test Buyer"
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

    test "email body contains order line items", %{store: store} do
      customer =
        create_customer!(store, %{
          email: "detail@example.com",
          name: "Detail Buyer"
        })

      # Create a product and variant so line items work
      product = create_product!(store, %{title: "Test Email Product"})
      variant = create_variant!(product, store, %{price: 12_000})

      order =
        create_order!(store, %{
          customer_id: customer.id,
          total: 12_000,
          subtotal: 12_000,
          currency: "GHS"
        })

      # Create a line item for the order
      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 1
      })
      |> Ash.create!()

      assert :ok =
               OrderNotificationWorker.perform(%Oban.Job{
                 args: %{"order_id" => order.id, "event" => "order_placed"}
               })

      assert_email_sent(fn email ->
        assert email.html_body =~ "Test Email Product"
        assert email.html_body =~ "GH₵120.00"
      end)
    end
  end
end
