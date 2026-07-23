defmodule Emakola.Notifications.TemplatesTest do
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Templates

  # ── Test data ──────────────────────────────────────────────────

  defp order do
    %{
      order_number: "ORD-20260322-ABC123",
      total: 50_000,
      currency: "GHS",
      store_id: "some-store-id"
    }
  end

  defp store do
    %{name: "Adwoa's Shop", id: "some-store-id", slug: "adwoas-shop"}
  end

  defp ngn_order do
    %{
      order_number: "ORD-20260322-NGN001",
      total: 150_000,
      currency: "NGN",
      store_id: "nigerian-store-id"
    }
  end

  defp ngn_store do
    %{name: "Lagos Mart", id: "nigerian-store-id", slug: "lagos-mart"}
  end

  # ── Amount formatting ──────────────────────────────────────────

  describe "format_amount/1" do
    test "formats pesewas to cedis with two decimal places" do
      assert Templates.format_amount(50_000) == "500.00"
    end

    test "formats small amounts correctly" do
      assert Templates.format_amount(199) == "1.99"
    end

    test "formats single-digit minor units with zero padding" do
      assert Templates.format_amount(5) == "0.05"
    end

    test "formats zero" do
      assert Templates.format_amount(0) == "0.00"
    end

    test "formats amounts with no minor units" do
      assert Templates.format_amount(100) == "1.00"
    end

    test "formats large amounts" do
      assert Templates.format_amount(1_000_000) == "10,000.00"
    end
  end

  # ── Customer SMS templates ─────────────────────────────────────

  describe "order_placed_sms/2" do
    test "includes order number, store name, and formatted amount" do
      msg = Templates.order_placed_sms(order(), store())
      assert msg =~ "ORD-20260322-ABC123"
      assert msg =~ "Adwoa's Shop"
      assert msg =~ "GH₵500.00"
      assert msg =~ "placed"
    end
  end

  describe "order_confirmed_sms/2" do
    test "includes order number, store name, and formatted amount" do
      msg = Templates.order_confirmed_sms(order(), store())
      assert msg =~ "ORD-20260322-ABC123"
      assert msg =~ "Adwoa's Shop"
      assert msg =~ "GH₵500.00"
      assert msg =~ "confirmed"
    end
  end

  describe "order_shipped_sms/2" do
    test "includes order number and store name" do
      msg = Templates.order_shipped_sms(order(), store())
      assert msg =~ "ORD-20260322-ABC123"
      assert msg =~ "Adwoa's Shop"
      assert msg =~ "shipped"
    end
  end

  describe "order_delivered_sms/2" do
    test "includes order number and store name" do
      msg = Templates.order_delivered_sms(order(), store())
      assert msg =~ "ORD-20260322-ABC123"
      assert msg =~ "Adwoa's Shop"
      assert msg =~ "delivered"
    end
  end

  describe "order_cancelled_sms/2" do
    test "includes order number and store name" do
      msg = Templates.order_cancelled_sms(order(), store())
      assert msg =~ "ORD-20260322-ABC123"
      assert msg =~ "Adwoa's Shop"
      assert msg =~ "cancelled"
    end
  end

  # ── Merchant SMS templates ─────────────────────────────────────

  describe "new_order_merchant_sms/2" do
    test "includes order number, amount, and dashboard reference" do
      msg = Templates.new_order_merchant_sms(order(), store())
      assert msg =~ "ORD-20260322-ABC123"
      assert msg =~ "GH₵500.00"
      assert msg =~ "Adwoa's Shop"
      assert msg =~ "dashboard"
    end
  end

  describe "order_cancelled_merchant_sms/2" do
    test "includes order number and amount" do
      msg = Templates.order_cancelled_merchant_sms(order(), store())
      assert msg =~ "ORD-20260322-ABC123"
      assert msg =~ "GH₵500.00"
      assert msg =~ "cancelled"
    end
  end

  # ── NGN currency ───────────────────────────────────────────────

  describe "Nigerian Naira support" do
    test "order_confirmed_sms uses NGN symbol" do
      msg = Templates.order_confirmed_sms(ngn_order(), ngn_store())
      assert msg =~ "₦1,500.00"
      assert msg =~ "Lagos Mart"
    end

    test "new_order_merchant_sms uses NGN symbol" do
      msg = Templates.new_order_merchant_sms(ngn_order(), ngn_store())
      assert msg =~ "₦1,500.00"
    end
  end

  # ── WhatsApp templates ─────────────────────────────────────────

  describe "whatsapp_template_for/1" do
    test "returns correct template name for each event" do
      assert Templates.whatsapp_template_for(:order_placed) == "order_placed"
      assert Templates.whatsapp_template_for(:order_confirmed) == "order_confirmed"
      assert Templates.whatsapp_template_for(:order_shipped) == "order_shipped"
      assert Templates.whatsapp_template_for(:order_delivered) == "order_delivered"
      assert Templates.whatsapp_template_for(:order_cancelled) == "order_cancelled"
    end
  end

  describe "whatsapp_params/2" do
    test "returns map with order details" do
      params = Templates.whatsapp_params(order(), store())
      assert params.order_number == "ORD-20260322-ABC123"
      assert params.store_name == "Adwoa's Shop"
      assert params.total == "500.00"
      assert params.currency == "GHS"
    end
  end

  # ── Supplier fulfillment templates ─────────────────────────────

  defp supplier do
    %{id: "supplier-id", name: "Kumasi Wholesale"}
  end

  defp supplier_order do
    %{
      order_number: "ORD-20260322-SUP001",
      shipping_address: %{
        "line_1" => "12 Market Road",
        "city" => "Kumasi",
        "region" => "Ashanti"
      }
    }
  end

  defp supplier_line_items do
    [
      %{quantity: 2, product_title: "Kente Cloth"},
      %{quantity: 1, product_title: "Beaded Necklace"}
    ]
  end

  describe "supplier_fulfillment_sms/3" do
    test "includes order number, item summary, and address" do
      msg =
        Templates.supplier_fulfillment_sms(supplier_order(), supplier(), supplier_line_items())

      assert msg =~ "ORD-20260322-SUP001"
      assert msg =~ "Kumasi Wholesale"
      assert msg =~ "2x Kente Cloth"
      assert msg =~ "1x Beaded Necklace"
      assert msg =~ "12 Market Road"
      assert msg =~ "Kumasi"
      assert msg =~ "tracking"
    end

    test "handles nil shipping address gracefully" do
      order = Map.put(supplier_order(), :shipping_address, nil)
      msg = Templates.supplier_fulfillment_sms(order, supplier(), supplier_line_items())
      assert msg =~ "(no address provided)"
      assert msg =~ "ORD-20260322-SUP001"
    end
  end

  describe "supplier_fulfillment_whatsapp_template/0" do
    test "returns the supplier_fulfillment template name" do
      assert Templates.supplier_fulfillment_whatsapp_template() == "supplier_fulfillment"
    end
  end

  describe "supplier_fulfillment_whatsapp_params/3" do
    test "returns map with supplier and order details" do
      params =
        Templates.supplier_fulfillment_whatsapp_params(
          supplier_order(),
          supplier(),
          supplier_line_items()
        )

      assert params.order_number == "ORD-20260322-SUP001"
      assert params.supplier_name == "Kumasi Wholesale"
      assert params.items =~ "2x Kente Cloth"
      assert params.ship_to =~ "Kumasi"
    end

    test "handles nil shipping address" do
      order = Map.put(supplier_order(), :shipping_address, nil)

      params =
        Templates.supplier_fulfillment_whatsapp_params(order, supplier(), supplier_line_items())

      assert params.ship_to == "(no address provided)"
    end
  end

  # ── Connection notification templates ──────────────────────────

  describe "connection notifications copy" do
    test "requested SMS names the reseller and points at the Earn Network page" do
      msg = Templates.connection_sms(:requested, "Adwoa's Boutique")
      assert msg =~ "Adwoa's Boutique"
      assert msg =~ "wants to stock your products"
      assert msg =~ "/admin/settings/supply-network"
    end

    test "approved SMS names the wholesaler and points at the catalog" do
      msg = Templates.connection_sms(:approved, "Kumasi Textiles")
      assert msg =~ "Kumasi Textiles"
      assert msg =~ "approved your connection"
      assert msg =~ "/admin/supply/catalog"
    end

    test "rejected SMS is honest and non-dead-end" do
      msg = Templates.connection_sms(:rejected, "Kumasi Textiles")
      assert msg =~ "declined"
      assert msg =~ "/admin/supply/catalog"
    end

    test "push payloads carry event-appropriate titles" do
      assert %{title: "New supply request", body: body} =
               Templates.connection_push(:requested, "Adwoa's Boutique")

      assert body =~ "Adwoa's Boutique"

      assert %{title: "Connection approved"} =
               Templates.connection_push(:approved, "Kumasi Textiles")

      assert %{title: "Connection declined"} =
               Templates.connection_push(:rejected, "Kumasi Textiles")
    end

    test "whatsapp template name and params" do
      assert Templates.whatsapp_template_for(:supply_connection) ==
               "supply_connection_update"

      params = Templates.connection_whatsapp_params(:requested, "Adwoa's Boutique")
      assert is_map(params)
    end
  end
end
