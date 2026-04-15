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
      assert Templates.format_amount(1_000_000) == "10000.00"
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
      assert msg =~ "₦1500.00"
      assert msg =~ "Lagos Mart"
    end

    test "new_order_merchant_sms uses NGN symbol" do
      msg = Templates.new_order_merchant_sms(ngn_order(), ngn_store())
      assert msg =~ "₦1500.00"
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
end
