defmodule Emakola.Payments.Gateways.CashOnDeliveryTest do
  @moduledoc "Tests for Cash on Delivery payment gateway."

  use ExUnit.Case, async: true

  alias Emakola.Payments.Gateways.CashOnDelivery

  describe "initiate_payment/1" do
    test "returns pending_cod status with COD reference" do
      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        order_id: "order-uuid-456"
      }

      assert {:ok, result} = CashOnDelivery.initiate_payment(params)
      assert result.status == :pending_cod
      assert String.starts_with?(result.reference, "COD-")
    end

    test "generates unique references for each payment" do
      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123"
      }

      {:ok, result1} = CashOnDelivery.initiate_payment(params)
      {:ok, result2} = CashOnDelivery.initiate_payment(params)

      assert result1.reference != result2.reference
    end

    test "includes amount and order_id in result" do
      params = %{
        amount: 300_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        order_id: "order-uuid-789"
      }

      assert {:ok, result} = CashOnDelivery.initiate_payment(params)
      assert result.amount == 300_000
      assert result.order_id == "order-uuid-789"
    end
  end

  describe "verify_payment/1" do
    test "returns pending_cod status" do
      assert {:ok, result} = CashOnDelivery.verify_payment("COD-some-reference")
      assert result.status == :pending_cod
    end

    test "returns the reference passed in" do
      reference = "COD-abc-123"
      assert {:ok, result} = CashOnDelivery.verify_payment(reference)
      assert result.reference == reference
    end
  end

  describe "process_refund/2" do
    test "returns not_supported error" do
      assert {:error, :not_supported} =
               CashOnDelivery.process_refund("COD-some-ref", 500_000)
    end
  end

  describe "verify_webhook/2" do
    test "returns not_supported error" do
      assert {:error, :not_supported} =
               CashOnDelivery.verify_webhook("body", %{})
    end
  end
end
