defmodule Emakola.Notifications.Emails.OrderEmailTest do
  use Emakola.DataCase, async: true

  alias Emakola.Notifications.Emails.OrderEmail

  # ── Test data helpers ──────────────────────────────────────────

  defp build_line_items do
    [
      %{
        product_title: "Ankara Print Dress",
        variant_sku: "APD-M-RED",
        quantity: 2,
        unit_price: 15_000,
        line_total: 30_000
      },
      %{
        product_title: "Kente Cloth Bag",
        variant_sku: "KCB-L",
        quantity: 1,
        unit_price: 8_500,
        line_total: 8_500
      }
    ]
  end

  defp build_order(attrs \\ []) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        order_number: "ORD-20260322-ABC123",
        status: :confirmed,
        subtotal: 38_500,
        total: 40_000,
        currency: "GHS",
        shipping_address: %{
          "name" => "Kwame Asante",
          "address_line_1" => "15 Oxford Street",
          "city" => "Accra",
          "region" => "Greater Accra",
          "phone" => "+233244123456"
        },
        line_items: build_line_items(),
        inserted_at: ~U[2026-03-22 10:30:00Z],
        notes: nil
      },
      Map.new(attrs)
    )
  end

  defp build_customer(attrs \\ []) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        name: "Kwame Asante",
        email: "kwame@example.com",
        phone: "+233244123456"
      },
      Map.new(attrs)
    )
  end

  defp build_store(attrs \\ []) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        name: "Accra Fashion Hub",
        slug: "accra-fashion-hub",
        currency: "GHS",
        contact_email: "hello@accrafashionhub.com",
        contact_phone: "+233302123456",
        whatsapp_number: "+233244999888",
        logo_url: "https://cdn.emakola.com/stores/accra-fashion-hub/logo.png",
        address: "15 Oxford Street, Osu",
        city: "Accra",
        region: "Greater Accra"
      },
      Map.new(attrs)
    )
  end

  # ── order_confirmation/3 ───────────────────────────────────────

  describe "order_confirmation/3" do
    test "returns a Swoosh.Email struct" do
      email = OrderEmail.order_confirmation(build_order(), build_customer(), build_store())
      assert %Swoosh.Email{} = email
    end

    test "sets correct subject with order number" do
      order = build_order()
      email = OrderEmail.order_confirmation(order, build_customer(), build_store())
      assert email.subject == "Order Confirmed — #{order.order_number}"
    end

    test "sets recipient to customer email" do
      customer = build_customer(email: "ama@example.com", name: "Ama Mensah")
      email = OrderEmail.order_confirmation(build_order(), customer, build_store())
      assert [{"Ama Mensah", "ama@example.com"}] = email.to
    end

    test "sets from address using store contact email" do
      store = build_store(contact_email: "shop@example.com", name: "My Shop")
      email = OrderEmail.order_confirmation(build_order(), build_customer(), store)
      assert {"My Shop", "shop@example.com"} = email.from
    end

    test "falls back to noreply when store has no contact_email" do
      store = build_store(contact_email: nil)
      email = OrderEmail.order_confirmation(build_order(), build_customer(), store)
      assert {"Accra Fashion Hub", "noreply@emakola.com"} = email.from
    end

    test "HTML body contains order number" do
      order = build_order(order_number: "ORD-20260322-XYZ789")
      email = OrderEmail.order_confirmation(order, build_customer(), build_store())
      assert email.html_body =~ "ORD-20260322-XYZ789"
    end

    test "HTML body contains store name" do
      store = build_store(name: "Kumasi Crafts")
      email = OrderEmail.order_confirmation(build_order(), build_customer(), store)
      assert email.html_body =~ "Kumasi Crafts"
    end

    test "HTML body contains line item product titles" do
      email = OrderEmail.order_confirmation(build_order(), build_customer(), build_store())
      assert email.html_body =~ "Ankara Print Dress"
      assert email.html_body =~ "Kente Cloth Bag"
    end

    test "HTML body contains line item quantities" do
      email = OrderEmail.order_confirmation(build_order(), build_customer(), build_store())
      # Quantity 2 for the dress
      assert email.html_body =~ "2"
      # Quantity 1 for the bag
      assert email.html_body =~ "1"
    end

    test "HTML body contains correctly formatted GHS prices" do
      email = OrderEmail.order_confirmation(build_order(), build_customer(), build_store())
      # unit_price 15000 pesewas = GH₵150.00
      assert email.html_body =~ "GH₵150.00"
      # unit_price 8500 pesewas = GH₵85.00
      assert email.html_body =~ "GH₵85.00"
      # total 40000 pesewas = GH₵400.00
      assert email.html_body =~ "GH₵400.00"
    end

    test "HTML body contains correctly formatted NGN prices" do
      order = build_order(currency: "NGN", total: 250_000, subtotal: 245_000)
      store = build_store(currency: "NGN")
      email = OrderEmail.order_confirmation(order, build_customer(), store)
      # total 250000 kobo = ₦2,500.00
      assert email.html_body =~ "₦2,500.00"
    end

    test "HTML body contains subtotal and total" do
      email = OrderEmail.order_confirmation(build_order(), build_customer(), build_store())
      # subtotal 38500 = GH₵385.00
      assert email.html_body =~ "GH₵385.00"
      # total 40000 = GH₵400.00
      assert email.html_body =~ "GH₵400.00"
    end

    test "HTML body contains shipping address" do
      email = OrderEmail.order_confirmation(build_order(), build_customer(), build_store())
      assert email.html_body =~ "Kwame Asante"
      assert email.html_body =~ "15 Oxford Street"
      assert email.html_body =~ "Accra"
    end

    test "HTML body contains track order link" do
      store = build_store(slug: "accra-fashion-hub")
      order = build_order(order_number: "ORD-20260322-ABC123")
      email = OrderEmail.order_confirmation(order, build_customer(), store)
      assert email.html_body =~ "/s/accra-fashion-hub/track/ORD-20260322-ABC123"
    end

    test "HTML body contains store WhatsApp link" do
      store = build_store(whatsapp_number: "+233244999888")
      email = OrderEmail.order_confirmation(build_order(), build_customer(), store)
      assert email.html_body =~ "wa.me/233244999888"
    end

    test "HTML body contains store contact info in footer" do
      store =
        build_store(contact_phone: "+233302123456", contact_email: "hello@accrafashionhub.com")

      email = OrderEmail.order_confirmation(build_order(), build_customer(), store)
      assert email.html_body =~ "+233302123456"
      assert email.html_body =~ "hello@accrafashionhub.com"
    end

    test "plain text fallback contains order number" do
      order = build_order(order_number: "ORD-20260322-XYZ789")
      email = OrderEmail.order_confirmation(order, build_customer(), build_store())
      assert email.text_body =~ "ORD-20260322-XYZ789"
    end

    test "plain text fallback contains total amount" do
      email = OrderEmail.order_confirmation(build_order(), build_customer(), build_store())
      assert email.text_body =~ "GH₵400.00"
    end

    test "plain text fallback contains line items" do
      email = OrderEmail.order_confirmation(build_order(), build_customer(), build_store())
      assert email.text_body =~ "Ankara Print Dress"
      assert email.text_body =~ "Kente Cloth Bag"
    end

    test "handles order with no shipping address gracefully" do
      order = build_order(shipping_address: nil)
      email = OrderEmail.order_confirmation(order, build_customer(), build_store())
      assert %Swoosh.Email{} = email
      # Should not crash, just omit address section
      refute email.html_body =~ "15 Oxford Street"
    end

    test "handles order with empty line items" do
      order = build_order(line_items: [])
      email = OrderEmail.order_confirmation(order, build_customer(), build_store())
      assert %Swoosh.Email{} = email
    end
  end

  # ── Supplier dispatch fee itemization ────────────────────────────
  # Regression for the pre-fix bug: shipping was `total - subtotal`, which
  # silently folded the supplier dispatch fee into the Shipping line.

  describe "order_confirmation/3 with a supplier dispatch fee" do
    test "shipping line shows the delivery fee alone; dispatch fee gets its own line" do
      order =
        build_order(
          delivery_fee: 1_000,
          dispatch_fee_total: 1_500,
          subtotal: 38_500,
          total: 41_000
        )

      email = OrderEmail.order_confirmation(order, build_customer(), build_store())

      assert email.html_body =~ "Supplier dispatch"
      assert email.html_body =~ "GH₵15.00"
      # Shipping is the delivery fee alone (GH₵10.00) — not delivery + dispatch (GH₵25.00).
      refute email.html_body =~ "GH₵25.00"

      assert email.text_body =~ "Supplier dispatch: GH₵15.00"
      assert email.text_body =~ "Shipping: GH₵10.00"
      refute email.text_body =~ "Shipping: GH₵25.00"
    end

    test "no dispatch line when dispatch_fee_total is 0" do
      order = build_order(delivery_fee: 1_000, dispatch_fee_total: 0, total: 39_500)
      email = OrderEmail.order_confirmation(order, build_customer(), build_store())

      refute email.html_body =~ "Supplier dispatch"
      refute email.text_body =~ "Supplier dispatch"
    end
  end
end
