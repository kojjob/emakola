defmodule Emakola.Notifications.Emails.OrderEmailReceiptTest do
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Emails.OrderEmail

  describe "order_confirmation/3 with discount" do
    test "includes discount line when discount_amount > 0" do
      order = %{
        order_number: "ORD-TEST",
        total: 8500,
        subtotal: 10_000,
        discount_amount: 1500,
        delivery_fee: 0,
        currency: "GHS",
        shipping_address: nil,
        line_items: [
          %{
            product_title: "Test Product",
            variant_sku: "SKU-1",
            quantity: 1,
            unit_price: 10_000,
            line_total: 10_000
          }
        ],
        inserted_at: ~U[2026-03-26 10:00:00Z]
      }

      customer = %{name: "Test Customer", email: "test@example.com"}

      store = %{
        name: "Test Store",
        slug: "test-store",
        contact_email: nil,
        contact_phone: nil,
        whatsapp_number: nil,
        logo_url: nil
      }

      email = OrderEmail.order_confirmation(order, customer, store)

      assert email.html_body =~ "Discount"
      assert email.html_body =~ "15.00"
    end

    test "does not show discount when discount_amount is 0" do
      order = %{
        order_number: "ORD-TEST",
        total: 10_000,
        subtotal: 10_000,
        discount_amount: 0,
        delivery_fee: 0,
        currency: "GHS",
        shipping_address: nil,
        line_items: [],
        inserted_at: ~U[2026-03-26 10:00:00Z]
      }

      customer = %{name: "Test", email: "test@example.com"}

      store = %{
        name: "Store",
        slug: "store",
        contact_email: nil,
        contact_phone: nil,
        whatsapp_number: nil,
        logo_url: nil
      }

      email = OrderEmail.order_confirmation(order, customer, store)

      refute email.html_body =~ "Discount"
    end

    test "does not show discount when discount_amount is nil" do
      order = %{
        order_number: "ORD-TEST",
        total: 10_000,
        subtotal: 10_000,
        discount_amount: nil,
        delivery_fee: 0,
        currency: "GHS",
        shipping_address: nil,
        line_items: [],
        inserted_at: ~U[2026-03-26 10:00:00Z]
      }

      customer = %{name: "Test", email: "test@example.com"}

      store = %{
        name: "Store",
        slug: "store",
        contact_email: nil,
        contact_phone: nil,
        whatsapp_number: nil,
        logo_url: nil
      }

      email = OrderEmail.order_confirmation(order, customer, store)

      refute email.html_body =~ "Discount"
    end
  end
end
