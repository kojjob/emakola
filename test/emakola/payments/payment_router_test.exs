defmodule Emakola.Payments.PaymentRouterTest do
  @moduledoc "Tests for PaymentRouter - routes payment methods to correct gateways."

  use ExUnit.Case, async: true

  alias Emakola.Payments.PaymentRouter
  alias Emakola.Payments.Gateways.Paystack
  alias Emakola.Payments.Gateways.CashOnDelivery

  @base_params %{
    amount: 500_000,
    email: "customer@example.com",
    currency: "GHS",
    store_id: "store-uuid-123",
    order_id: "order-uuid-456",
    callback_url: "https://example.com/callback"
  }

  describe "route_payment/2 for MTN MoMo" do
    test "routes to Paystack with mobile_money channel and mtn provider" do
      params = Map.put(@base_params, :phone, "0241234567")

      assert {:ok, gateway, gateway_params} = PaymentRouter.route_payment(:momo_mtn, params)
      assert gateway == Paystack
      assert gateway_params.channel == "mobile_money"
      assert gateway_params.mobile_money_provider == "mtn"
      assert gateway_params.phone == "0241234567"
    end
  end

  describe "route_payment/2 for Vodafone Cash" do
    test "routes to Paystack with mobile_money channel and vod provider" do
      params = Map.put(@base_params, :phone, "0201234567")

      assert {:ok, gateway, gateway_params} = PaymentRouter.route_payment(:momo_vodafone, params)
      assert gateway == Paystack
      assert gateway_params.channel == "mobile_money"
      assert gateway_params.mobile_money_provider == "vod"
      assert gateway_params.phone == "0201234567"
    end
  end

  describe "route_payment/2 for AirtelTigo" do
    test "routes to Paystack with mobile_money channel and tgo provider" do
      params = Map.put(@base_params, :phone, "0271234567")

      assert {:ok, gateway, gateway_params} =
               PaymentRouter.route_payment(:momo_airteltigo, params)

      assert gateway == Paystack
      assert gateway_params.channel == "mobile_money"
      assert gateway_params.mobile_money_provider == "tgo"
      assert gateway_params.phone == "0271234567"
    end
  end

  describe "route_payment/2 for card" do
    test "routes to Paystack with card channel" do
      assert {:ok, gateway, gateway_params} = PaymentRouter.route_payment(:card, @base_params)
      assert gateway == Paystack
      assert gateway_params.channel == "card"
      refute Map.has_key?(gateway_params, :mobile_money_provider)
    end
  end

  describe "route_payment/2 for COD" do
    test "routes to CashOnDelivery gateway" do
      assert {:ok, gateway, gateway_params} = PaymentRouter.route_payment(:cod, @base_params)
      assert gateway == CashOnDelivery
      assert gateway_params.amount == 500_000
    end
  end

  describe "route_payment/2 with invalid method" do
    test "returns error for unknown payment method" do
      assert {:error, {:unknown_payment_method, :bitcoin}} =
               PaymentRouter.route_payment(:bitcoin, @base_params)
    end
  end

  describe "route_payment/2 preserves base params" do
    test "all routed params include amount, email, currency, store_id" do
      params = Map.put(@base_params, :phone, "0241234567")

      methods = [
        {:momo_mtn, Paystack},
        {:momo_vodafone, Paystack},
        {:momo_airteltigo, Paystack},
        {:card, Paystack},
        {:cod, CashOnDelivery}
      ]

      for {method, expected_gateway} <- methods do
        {:ok, gateway, gateway_params} = PaymentRouter.route_payment(method, params)
        assert gateway == expected_gateway
        assert gateway_params.amount == 500_000
        assert gateway_params.email == "customer@example.com"
        assert gateway_params.currency == "GHS"
        assert gateway_params.store_id == "store-uuid-123"
      end
    end
  end
end
