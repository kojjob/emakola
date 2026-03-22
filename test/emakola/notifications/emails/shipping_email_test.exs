defmodule Emakola.Notifications.Emails.ShippingEmailTest do
  use Emakola.DataCase, async: true

  alias Emakola.Notifications.Emails.ShippingEmail

  # ── Test data helpers ──────────────────────────────────────────

  defp build_order(attrs \\ []) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        order_number: "ORD-20260322-SHIP01",
        status: :shipped,
        subtotal: 20_000,
        total: 22_000,
        currency: "GHS",
        shipping_address: %{
          "name" => "Ama Mensah",
          "address_line_1" => "42 Liberation Road",
          "city" => "Kumasi",
          "region" => "Ashanti"
        },
        line_items: [],
        inserted_at: ~U[2026-03-22 10:30:00Z]
      },
      Map.new(attrs)
    )
  end

  defp build_customer(attrs \\ []) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        name: "Ama Mensah",
        email: "ama@example.com",
        phone: "+233244567890"
      },
      Map.new(attrs)
    )
  end

  defp build_store(attrs \\ []) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        name: "Kumasi Crafts",
        slug: "kumasi-crafts",
        currency: "GHS",
        contact_email: "info@kumasicrafts.com",
        contact_phone: "+233322654321",
        whatsapp_number: "+233244888777",
        logo_url: nil,
        address: nil,
        city: "Kumasi",
        region: "Ashanti"
      },
      Map.new(attrs)
    )
  end

  defp build_tracking_info(attrs \\ []) do
    Map.merge(
      %{
        carrier: "Ghana Post",
        tracking_number: "GP-2026-ABC123",
        tracking_url: "https://ghanapost.com/track/GP-2026-ABC123",
        estimated_delivery: "March 25-27, 2026"
      },
      Map.new(attrs)
    )
  end

  # ── order_shipped/4 ────────────────────────────────────────────

  describe "order_shipped/4" do
    test "returns a Swoosh.Email struct" do
      email =
        ShippingEmail.order_shipped(
          build_order(),
          build_customer(),
          build_store(),
          build_tracking_info()
        )

      assert %Swoosh.Email{} = email
    end

    test "sets correct subject with order number" do
      order = build_order(order_number: "ORD-20260322-SHIP01")

      email =
        ShippingEmail.order_shipped(order, build_customer(), build_store(), build_tracking_info())

      assert email.subject == "Your Order ORD-20260322-SHIP01 Has Shipped!"
    end

    test "sets recipient to customer email" do
      customer = build_customer(email: "kofi@example.com", name: "Kofi Boateng")

      email =
        ShippingEmail.order_shipped(
          build_order(),
          customer,
          build_store(),
          build_tracking_info()
        )

      assert [{"Kofi Boateng", "kofi@example.com"}] = email.to
    end

    test "HTML body contains tracking number" do
      tracking = build_tracking_info(tracking_number: "GP-2026-XYZ999")

      email =
        ShippingEmail.order_shipped(build_order(), build_customer(), build_store(), tracking)

      assert email.html_body =~ "GP-2026-XYZ999"
    end

    test "HTML body contains tracking URL as link" do
      tracking = build_tracking_info(tracking_url: "https://ghanapost.com/track/GP-123")

      email =
        ShippingEmail.order_shipped(build_order(), build_customer(), build_store(), tracking)

      assert email.html_body =~ "https://ghanapost.com/track/GP-123"
    end

    test "HTML body contains carrier name" do
      tracking = build_tracking_info(carrier: "DHL Express")

      email =
        ShippingEmail.order_shipped(build_order(), build_customer(), build_store(), tracking)

      assert email.html_body =~ "DHL Express"
    end

    test "HTML body contains estimated delivery" do
      tracking = build_tracking_info(estimated_delivery: "March 25-27, 2026")

      email =
        ShippingEmail.order_shipped(build_order(), build_customer(), build_store(), tracking)

      assert email.html_body =~ "March 25-27, 2026"
    end

    test "HTML body contains shipping address" do
      email =
        ShippingEmail.order_shipped(
          build_order(),
          build_customer(),
          build_store(),
          build_tracking_info()
        )

      assert email.html_body =~ "42 Liberation Road"
      assert email.html_body =~ "Kumasi"
    end

    test "plain text fallback contains tracking number" do
      tracking = build_tracking_info(tracking_number: "GP-2026-ABC123")

      email =
        ShippingEmail.order_shipped(build_order(), build_customer(), build_store(), tracking)

      assert email.text_body =~ "GP-2026-ABC123"
    end

    test "plain text fallback contains tracking URL" do
      tracking = build_tracking_info(tracking_url: "https://ghanapost.com/track/GP-123")

      email =
        ShippingEmail.order_shipped(build_order(), build_customer(), build_store(), tracking)

      assert email.text_body =~ "https://ghanapost.com/track/GP-123"
    end

    test "plain text fallback contains estimated delivery" do
      email =
        ShippingEmail.order_shipped(
          build_order(),
          build_customer(),
          build_store(),
          build_tracking_info()
        )

      assert email.text_body =~ "March 25-27, 2026"
    end

    test "handles nil tracking_url gracefully" do
      tracking = build_tracking_info(tracking_url: nil)

      email =
        ShippingEmail.order_shipped(build_order(), build_customer(), build_store(), tracking)

      assert %Swoosh.Email{} = email
    end

    test "handles nil estimated_delivery gracefully" do
      tracking = build_tracking_info(estimated_delivery: nil)

      email =
        ShippingEmail.order_shipped(build_order(), build_customer(), build_store(), tracking)

      assert %Swoosh.Email{} = email
    end
  end
end
