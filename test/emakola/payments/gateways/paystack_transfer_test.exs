defmodule Emakola.Payments.Gateways.PaystackTransferTest do
  @moduledoc """
  Paystack transfer rails (payout engine slice 1): create a mobile-money
  transfer recipient and initiate a transfer, mapping params and normalising
  the gateway response.
  """
  use ExUnit.Case, async: true
  import Mox

  alias Emakola.Payments.Gateways.Paystack
  alias Emakola.Payments.PaystackClientMock

  setup :verify_on_exit!

  describe "create_transfer_recipient/1" do
    test "maps MoMo params and returns the recipient code" do
      expect(PaystackClientMock, :create_transfer_recipient, fn params ->
        assert params.type == "mobile_money"
        assert params.name == "Kwame"
        assert params.account_number == "0244123456"
        assert params.bank_code == "MTN"
        assert params.currency == "GHS"
        {:ok, %{"status" => true, "data" => %{"recipient_code" => "RCP_abc"}}}
      end)

      assert {:ok, %{recipient_code: "RCP_abc"}} =
               Paystack.create_transfer_recipient(%{
                 type: "mobile_money",
                 name: "Kwame",
                 account_number: "0244123456",
                 bank_code: "MTN",
                 currency: "GHS"
               })
    end

    test "passes a gateway error through" do
      expect(PaystackClientMock, :create_transfer_recipient, fn _ -> {:error, :timeout} end)

      assert {:error, {:gateway_error, :timeout}} =
               Paystack.create_transfer_recipient(%{type: "mobile_money"})
    end

    test "surfaces a Paystack failure message" do
      expect(PaystackClientMock, :create_transfer_recipient, fn _ ->
        {:ok, %{"status" => false, "message" => "Invalid recipient"}}
      end)

      assert {:error, {:paystack_error, "Invalid recipient"}} =
               Paystack.create_transfer_recipient(%{type: "mobile_money"})
    end
  end

  describe "initiate_transfer/1" do
    test "maps params and returns the transfer code and status" do
      expect(PaystackClientMock, :initiate_transfer, fn params ->
        assert params.source == "balance"
        assert params.amount == 80_000
        assert params.recipient == "RCP_abc"
        assert params.reference == "PO-xyz"
        assert params.currency == "GHS"
        {:ok, %{"status" => true, "data" => %{"transfer_code" => "TRF_x", "status" => "pending"}}}
      end)

      assert {:ok, %{transfer_code: "TRF_x", status: "pending"}} =
               Paystack.initiate_transfer(%{
                 source: "balance",
                 amount: 80_000,
                 recipient: "RCP_abc",
                 reason: "Payout",
                 reference: "PO-xyz",
                 currency: "GHS"
               })
    end

    test "passes a gateway error through" do
      expect(PaystackClientMock, :initiate_transfer, fn _ -> {:error, :timeout} end)

      assert {:error, {:gateway_error, :timeout}} =
               Paystack.initiate_transfer(%{reference: "PO-xyz"})
    end
  end
end
