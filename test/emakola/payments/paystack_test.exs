defmodule Emakola.Payments.Gateways.PaystackTest do
  use ExUnit.Case, async: true

  import Mox

  alias Emakola.Payments.Gateways.Paystack

  setup :verify_on_exit!

  @secret "sk_test_default_secret"

  # -- initiate_payment/1 ---------------------------------------------------

  describe "initiate_payment/1" do
    test "returns authorization_url on success" do
      Emakola.Payments.PaystackClientMock
      |> expect(:initialize_transaction, fn params ->
        assert params.amount == 500_000
        assert params.email == "customer@example.com"
        assert params.currency == "GHS"
        assert String.starts_with?(params.reference, "PAY-")

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/abc123",
             "access_code" => "abc123",
             "reference" => params.reference
           }
         }}
      end)

      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        order_id: "order-uuid-456",
        callback_url: "https://example.com/callback"
      }

      assert {:ok, result} = Paystack.initiate_payment(params)
      assert result.authorization_url == "https://checkout.paystack.com/abc123"
      assert String.starts_with?(result.reference, "PAY-")
      assert result.access_code == "abc123"
    end

    test "returns error when Paystack returns status false" do
      Emakola.Payments.PaystackClientMock
      |> expect(:initialize_transaction, fn _params ->
        {:ok, %{"status" => false, "message" => "Invalid amount"}}
      end)

      params = %{
        amount: 0,
        email: "bad@example.com",
        currency: "GHS",
        store_id: "store-uuid-123"
      }

      assert {:error, {:paystack_error, "Invalid amount"}} = Paystack.initiate_payment(params)
    end

    test "returns gateway_error on network failure" do
      Emakola.Payments.PaystackClientMock
      |> expect(:initialize_transaction, fn _params ->
        {:error, :timeout}
      end)

      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123"
      }

      assert {:error, {:gateway_error, :timeout}} = Paystack.initiate_payment(params)
    end
  end

  # -- verify_payment/1 ----------------------------------------------------

  describe "verify_payment/1" do
    test "returns payment details on successful verification" do
      reference = "PAY-store-1234567890-abc"

      Emakola.Payments.PaystackClientMock
      |> expect(:verify_transaction, fn ref ->
        assert ref == reference

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "status" => "success",
             "amount" => 500_000,
             "currency" => "GHS",
             "reference" => reference,
             "gateway_response" => "Successful",
             "channel" => "mobile_money",
             "paid_at" => "2026-03-22T10:00:00.000Z"
           }
         }}
      end)

      assert {:ok, result} = Paystack.verify_payment(reference)
      assert result.status == :success
      assert result.amount == 500_000
      assert result.currency == "GHS"
      assert result.reference == reference
      assert result.gateway_response == "Successful"
      assert result.channel == "mobile_money"
    end

    test "returns failed status for declined payment" do
      reference = "PAY-store-1234567890-xyz"

      Emakola.Payments.PaystackClientMock
      |> expect(:verify_transaction, fn _ref ->
        {:ok,
         %{
           "status" => true,
           "data" => %{
             "status" => "failed",
             "amount" => 500_000,
             "currency" => "GHS",
             "reference" => reference,
             "gateway_response" => "Declined"
           }
         }}
      end)

      assert {:ok, result} = Paystack.verify_payment(reference)
      assert result.status == :failed
    end

    test "maps abandoned status to failed" do
      Emakola.Payments.PaystackClientMock
      |> expect(:verify_transaction, fn _ref ->
        {:ok,
         %{
           "status" => true,
           "data" => %{
             "status" => "abandoned",
             "amount" => 500_000,
             "currency" => "GHS",
             "reference" => "ref-123"
           }
         }}
      end)

      assert {:ok, result} = Paystack.verify_payment("ref-123")
      assert result.status == :failed
    end

    test "returns error on Paystack API error response" do
      Emakola.Payments.PaystackClientMock
      |> expect(:verify_transaction, fn _ref ->
        {:ok, %{"status" => false, "message" => "Transaction not found"}}
      end)

      assert {:error, {:paystack_error, "Transaction not found"}} =
               Paystack.verify_payment("bad-ref")
    end

    test "returns error on network failure" do
      Emakola.Payments.PaystackClientMock
      |> expect(:verify_transaction, fn _ref ->
        {:error, %{reason: :timeout}}
      end)

      assert {:error, {:gateway_error, _}} = Paystack.verify_payment("some-ref")
    end
  end

  # -- process_refund/2 ----------------------------------------------------

  describe "process_refund/2" do
    test "returns refund confirmation on success" do
      reference = "PAY-store-1234567890-abc"
      refund_amount = 250_000

      Emakola.Payments.PaystackClientMock
      |> expect(:create_refund, fn params ->
        assert params.transaction == reference
        assert params.amount == refund_amount

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "transaction" => %{"reference" => reference},
             "amount" => refund_amount,
             "status" => "processed",
             "refund_reference" => "refund-123"
           }
         }}
      end)

      assert {:ok, result} = Paystack.process_refund(reference, refund_amount)
      assert result.amount == refund_amount
      assert result.status == :processed
      assert result.reference == reference
      assert result.refund_reference == "refund-123"
    end

    test "returns error when refund fails at Paystack" do
      Emakola.Payments.PaystackClientMock
      |> expect(:create_refund, fn _params ->
        {:ok, %{"status" => false, "message" => "Transaction not found"}}
      end)

      assert {:error, {:paystack_error, "Transaction not found"}} =
               Paystack.process_refund("bad-ref", 100)
    end

    test "returns gateway_error on network failure" do
      Emakola.Payments.PaystackClientMock
      |> expect(:create_refund, fn _params ->
        {:error, :econnrefused}
      end)

      assert {:error, {:gateway_error, :econnrefused}} =
               Paystack.process_refund("ref", 100)
    end
  end

  # -- verify_webhook/2 ----------------------------------------------------

  describe "verify_webhook/2" do
    test "returns :ok with valid HMAC signature" do
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})

      signature =
        :crypto.mac(:hmac, :sha512, @secret, body)
        |> Base.encode16(case: :lower)

      headers = %{"x-paystack-signature" => signature}

      assert :ok = Paystack.verify_webhook(body, headers)
    end

    test "returns error with invalid signature" do
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})
      headers = %{"x-paystack-signature" => "invalid_signature_here"}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(body, headers)
    end

    test "returns error when signature header is missing" do
      body = ~s({"event":"charge.success"})
      headers = %{}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(body, headers)
    end

    test "returns error when signature is nil" do
      body = ~s({"event":"charge.success"})
      headers = %{"x-paystack-signature" => nil}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(body, headers)
    end

    test "HMAC SHA512 computation is correct" do
      message = "test_message_payload"

      expected =
        :crypto.mac(:hmac, :sha512, @secret, message)
        |> Base.encode16(case: :lower)

      headers = %{"x-paystack-signature" => expected}
      assert :ok = Paystack.verify_webhook(message, headers)

      wrong_sig =
        :crypto.mac(:hmac, :sha512, "wrong_key", message)
        |> Base.encode16(case: :lower)

      assert {:error, :invalid_signature} =
               Paystack.verify_webhook(message, %{"x-paystack-signature" => wrong_sig})
    end
  end

  # -- reference generation -------------------------------------------------

  describe "reference generation" do
    test "generates unique references with proper format" do
      params = %{
        amount: 1000,
        email: "test@example.com",
        currency: "GHS",
        store_id: "abcdef12-3456-7890-abcd-ef1234567890"
      }

      Emakola.Payments.PaystackClientMock
      |> expect(:initialize_transaction, 2, fn body ->
        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/test",
             "access_code" => "test",
             "reference" => body.reference
           }
         }}
      end)

      {:ok, result1} = Paystack.initiate_payment(params)
      {:ok, result2} = Paystack.initiate_payment(params)

      assert result1.reference != result2.reference
      assert result1.reference =~ ~r/^PAY-[a-z0-9]+-\d+-[a-z0-9]+$/
    end
  end
end
