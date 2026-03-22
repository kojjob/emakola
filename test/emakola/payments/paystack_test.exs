defmodule Emakola.Payments.Gateways.PaystackTest do
  use ExUnit.Case, async: true

  import Mox

  alias Emakola.Payments.Gateways.Paystack

  setup :verify_on_exit!

  @secret "sk_test_default_secret"

  setup do
    :ok
  end

  describe "initiate_payment/1" do
    test "returns authorization_url on success" do
      Emakola.HTTPClientMock
      |> expect(:post, fn url, opts ->
        assert url == "https://api.paystack.co/transaction/initialize"
        assert {"Authorization", "Bearer sk_test_default_secret"} in opts[:headers]

        body = opts[:json]
        assert body.amount == 500_000
        assert body.email == "customer@example.com"
        assert body.currency == "GHS"
        assert String.starts_with?(body.reference, "PAY-")

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/abc123",
             "access_code" => "abc123",
             "reference" => body.reference
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

    test "returns error on API failure" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, _opts ->
        {:error, %{status: 400, body: %{"status" => false, "message" => "Invalid amount"}}}
      end)

      params = %{
        amount: 0,
        email: "bad@example.com",
        currency: "GHS",
        store_id: "store-uuid-123"
      }

      assert {:error, _reason} = Paystack.initiate_payment(params)
    end
  end

  describe "verify_payment/1" do
    test "returns payment details on successful verification" do
      reference = "PAY-store-1234567890-abc"

      Emakola.HTTPClientMock
      |> expect(:get, fn url, opts ->
        assert url == "https://api.paystack.co/transaction/verify/#{reference}"
        assert {"Authorization", "Bearer sk_test_default_secret"} in opts[:headers]

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
    end

    test "returns failed status for declined payment" do
      reference = "PAY-store-1234567890-xyz"

      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
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

    test "returns error on network failure" do
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:error, %Req.TransportError{reason: :timeout}}
      end)

      assert {:error, _reason} = Paystack.verify_payment("some-ref")
    end
  end

  describe "process_refund/2" do
    test "returns refund confirmation on success" do
      reference = "PAY-store-1234567890-abc"
      refund_amount = 250_000

      Emakola.HTTPClientMock
      |> expect(:post, fn url, opts ->
        assert url == "https://api.paystack.co/refund"
        assert {"Authorization", "Bearer sk_test_default_secret"} in opts[:headers]

        body = opts[:json]
        assert body.transaction == reference
        assert body.amount == refund_amount

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
    end

    test "returns error when refund fails" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, _opts ->
        {:error, %{status: 400, body: %{"status" => false, "message" => "Transaction not found"}}}
      end)

      assert {:error, _reason} = Paystack.process_refund("bad-ref", 100)
    end
  end

  describe "verify_webhook/2" do
    test "returns :ok with valid HMAC signature" do
      secret = @secret
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})

      signature =
        :crypto.mac(:hmac, :sha512, secret, body)
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

    test "HMAC SHA512 computation is correct" do
      # Verify that verify_webhook uses HMAC-SHA512 with the configured secret
      message = "test_message_payload"

      # Compute expected signature using the configured test secret
      expected =
        :crypto.mac(:hmac, :sha512, @secret, message)
        |> Base.encode16(case: :lower)

      headers = %{"x-paystack-signature" => expected}

      assert :ok = Paystack.verify_webhook(message, headers)

      # Also verify a wrong key produces a different hash
      wrong_sig =
        :crypto.mac(:hmac, :sha512, "wrong_key", message)
        |> Base.encode16(case: :lower)

      assert {:error, :invalid_signature} =
               Paystack.verify_webhook(message, %{"x-paystack-signature" => wrong_sig})
    end
  end

  describe "reference generation" do
    test "generates unique references with proper format" do
      params = %{
        amount: 1000,
        email: "test@example.com",
        currency: "GHS",
        store_id: "abcdef12-3456-7890-abcd-ef1234567890"
      }

      # We need two calls to check uniqueness
      Emakola.HTTPClientMock
      |> expect(:post, 2, fn _url, opts ->
        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/test",
             "access_code" => "test",
             "reference" => opts[:json].reference
           }
         }}
      end)

      {:ok, result1} = Paystack.initiate_payment(params)
      {:ok, result2} = Paystack.initiate_payment(params)

      # References should be unique
      assert result1.reference != result2.reference
      # Format: PAY-{store_prefix}-{timestamp}-{random}
      assert result1.reference =~ ~r/^PAY-[a-z0-9]+-\d+-[a-z0-9]+$/
    end
  end
end
