defmodule Emakola.Notifications.Emails.DeliveryEmailTest do
  use Emakola.DataCase, async: true

  alias Emakola.Notifications.Emails.DeliveryEmail

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
        order_number: "ORD-20260325-DEL01",
        status: :delivered,
        subtotal: 38_500,
        total: 40_000,
        currency: "GHS",
        shipping_address: %{
          "name" => "Kwame Asante",
          "address_line_1" => "15 Oxford Street",
          "city" => "Accra",
          "region" => "Greater Accra"
        },
        line_items: build_line_items(),
        inserted_at: ~U[2026-03-25 14:00:00Z]
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
        logo_url: "https://cdn.emakola.com/stores/accra-fashion-hub/logo.png"
      },
      Map.new(attrs)
    )
  end

  # ── order_delivered/3 ──────────────────────────────────────────

  describe "order_delivered/3" do
    test "returns a Swoosh.Email struct" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert %Swoosh.Email{} = email
    end

    test "sets correct subject with order number" do
      order = build_order(order_number: "ORD-20260325-DEL01")
      email = DeliveryEmail.order_delivered(order, build_customer(), build_store())
      assert email.subject == "Your Order ORD-20260325-DEL01 Has Been Delivered!"
    end

    test "sets recipient to customer email" do
      customer = build_customer(email: "ama@example.com", name: "Ama Mensah")
      email = DeliveryEmail.order_delivered(build_order(), customer, build_store())
      assert [{"Ama Mensah", "ama@example.com"}] = email.to
    end

    test "sets from address using store contact email" do
      store = build_store(contact_email: "shop@example.com", name: "My Shop")
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      assert {"My Shop", "shop@example.com"} = email.from
    end

    test "falls back to noreply when store has no contact_email" do
      store = build_store(contact_email: nil)
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      assert {"Accra Fashion Hub", "noreply@makola.io"} = email.from
    end

    # ── HTML body content ──────────────────────────────────────────

    test "HTML body contains order number" do
      order = build_order(order_number: "ORD-20260325-XYZ")
      email = DeliveryEmail.order_delivered(order, build_customer(), build_store())
      assert email.html_body =~ "ORD-20260325-XYZ"
    end

    test "HTML body contains store name" do
      store = build_store(name: "Kumasi Crafts")
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      assert email.html_body =~ "Kumasi Crafts"
    end

    test "HTML body contains delivery confirmation message" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.html_body =~ "has been delivered"
    end

    test "HTML body contains thank you message" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.html_body =~ "Thank you for shopping"
    end

    test "HTML body contains review prompt" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.html_body =~ "Leave a Review"
    end

    test "HTML body contains review link with store slug and order number" do
      store = build_store(slug: "accra-fashion-hub")
      order = build_order(order_number: "ORD-20260325-DEL01")
      email = DeliveryEmail.order_delivered(order, build_customer(), store)
      assert email.html_body =~ "/accra-fashion-hub/orders/ORD-20260325-DEL01/review"
    end

    test "HTML body contains line item product titles" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.html_body =~ "Ankara Print Dress"
      assert email.html_body =~ "Kente Cloth Bag"
    end

    test "HTML body contains formatted GHS total" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.html_body =~ "GH₵400.00"
    end

    test "HTML body contains formatted NGN prices" do
      order = build_order(currency: "NGN", total: 250_000)
      email = DeliveryEmail.order_delivered(order, build_customer(), build_store())
      assert email.html_body =~ "₦2,500.00"
    end

    test "HTML body uses navy/gold branding colors" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      # Navy header
      assert email.html_body =~ "#1a1a2e"
      # Gold accent
      assert email.html_body =~ "#d4a843"
    end

    test "HTML body contains customer name in greeting" do
      customer = build_customer(name: "Kofi Boateng")
      email = DeliveryEmail.order_delivered(build_order(), customer, build_store())
      assert email.html_body =~ "Hi Kofi Boateng"
    end

    test "HTML body contains store WhatsApp link" do
      store = build_store(whatsapp_number: "+233244999888")
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      assert email.html_body =~ "wa.me/233244999888"
    end

    test "HTML body contains store contact info in footer" do
      store = build_store(contact_phone: "+233302123456", contact_email: "hello@test.com")
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      assert email.html_body =~ "+233302123456"
      assert email.html_body =~ "hello@test.com"
    end

    test "HTML body contains store logo when present" do
      store = build_store(logo_url: "https://cdn.example.com/logo.png")
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      assert email.html_body =~ "https://cdn.example.com/logo.png"
    end

    test "HTML body omits logo when not present" do
      store = build_store(logo_url: nil)
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      refute email.html_body =~ "<img"
    end

    # ── Plain text body ────────────────────────────────────────────

    test "plain text contains order number" do
      order = build_order(order_number: "ORD-20260325-DEL01")
      email = DeliveryEmail.order_delivered(order, build_customer(), build_store())
      assert email.text_body =~ "ORD-20260325-DEL01"
    end

    test "plain text contains delivery confirmation" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.text_body =~ "has been delivered"
    end

    test "plain text contains total amount" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.text_body =~ "GH₵400.00"
    end

    test "plain text contains review link" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.text_body =~ "/review"
    end

    test "plain text contains line items" do
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), build_store())
      assert email.text_body =~ "Ankara Print Dress"
      assert email.text_body =~ "Kente Cloth Bag"
    end

    # ── Edge cases ─────────────────────────────────────────────────

    test "handles order with empty line items" do
      order = build_order(line_items: [])
      email = DeliveryEmail.order_delivered(order, build_customer(), build_store())
      assert %Swoosh.Email{} = email
      refute email.html_body =~ "Items Delivered"
    end

    test "handles customer with nil name" do
      customer = build_customer(name: nil)
      email = DeliveryEmail.order_delivered(build_order(), customer, build_store())
      assert email.html_body =~ "Hi there"
    end

    test "handles store with no WhatsApp number" do
      store = build_store(whatsapp_number: nil)
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      assert %Swoosh.Email{} = email
      refute email.html_body =~ "wa.me"
    end

    test "handles store with no contact info" do
      store = build_store(contact_email: nil, contact_phone: nil)
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      assert %Swoosh.Email{} = email
    end

    test "escapes HTML in customer name" do
      customer = build_customer(name: "<script>alert('xss')</script>")
      email = DeliveryEmail.order_delivered(build_order(), customer, build_store())
      refute email.html_body =~ "<script>"
      assert email.html_body =~ "&lt;script&gt;"
    end

    test "escapes HTML in store name" do
      store = build_store(name: "Store & <b>Bold</b>")
      email = DeliveryEmail.order_delivered(build_order(), build_customer(), store)
      refute email.html_body =~ "<b>Bold</b>"
      assert email.html_body =~ "Store &amp; &lt;b&gt;Bold&lt;/b&gt;"
    end
  end
end
