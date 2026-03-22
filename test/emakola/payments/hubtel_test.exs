defmodule Emakola.Payments.Gateways.HubtelTest do
  use Emakola.DataCase, async: true

  import Mox

  alias Emakola.Payments.Gateways.Hubtel

  setup :verify_on_exit!

  describe "initiate_payment/1" do
    test "converts pesewas to cedis correctly (500000 pesewas -> 5000.00 cedis)" do
      Emakola.HTTPClientMock
      |> expect(:post, fn url, opts ->
        # Verify the URL
        assert url =~ "/v2/receive/mobile-money"

        # Extract body from opts and verify amount conversion
        body = Keyword.get(opts, :json)
        assert body["Amount"] == 5000.00

        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "CheckoutUrl" => "https://pay.hubtel.com/checkout/abc123",
             "CheckoutId" => "abc123",
             "ClientReference" => body["ClientReference"]
           }
         }}
      end)

      params = %{
        amount: 500_000,
        store_id: "store-abc-123",
        order_reference: "ORD-001",
        description: "Payment for order",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/orders/ORD-001",
        channel: "mtn-gh"
      }

      assert {:ok, result} = Hubtel.initiate_payment(params)
      assert result.checkout_url == "https://pay.hubtel.com/checkout/abc123"
      assert result.checkout_id == "abc123"
      assert is_binary(result.reference)
    end

    test "returns checkout URL on success" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "CheckoutUrl" => "https://pay.hubtel.com/checkout/xyz789",
             "CheckoutId" => "xyz789",
             "ClientReference" => "HUB-store-1234567890-abcdef"
           }
         }}
      end)

      params = %{
        amount: 10_000,
        store_id: "store-def-456",
        order_reference: "ORD-002",
        description: "Payment for order",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/orders/ORD-002",
        channel: "vodafone-gh"
      }

      assert {:ok, result} = Hubtel.initiate_payment(params)
      assert result.checkout_url == "https://pay.hubtel.com/checkout/xyz789"
      assert result.checkout_id == "xyz789"
    end

    test "sends correct Basic Auth header" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        headers = Keyword.get(opts, :headers, [])
        auth_header = Enum.find(headers, fn {k, _v} -> k == "authorization" end)
        assert auth_header != nil

        {_, auth_value} = auth_header
        expected = "Basic " <> Base.encode64("test_client_id:test_client_secret")
        assert auth_value == expected

        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "CheckoutUrl" => "https://pay.hubtel.com/checkout/test",
             "CheckoutId" => "test",
             "ClientReference" => "ref"
           }
         }}
      end)

      params = %{
        amount: 1000,
        store_id: "store-test",
        order_reference: "ORD-003",
        description: "Test",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/return",
        channel: "mtn-gh"
      }

      assert {:ok, _result} = Hubtel.initiate_payment(params)
    end

    test "generates reference with HUB prefix and store_id" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = Keyword.get(opts, :json)
        ref = body["ClientReference"]

        assert String.starts_with?(ref, "HUB-store1-")

        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "CheckoutUrl" => "https://pay.hubtel.com/checkout/test",
             "CheckoutId" => "test",
             "ClientReference" => ref
           }
         }}
      end)

      params = %{
        amount: 1000,
        store_id: "store123-def-456",
        order_reference: "ORD-004",
        description: "Test",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/return",
        channel: "mtn-gh"
      }

      assert {:ok, _result} = Hubtel.initiate_payment(params)
    end

    test "handles Hubtel error response codes" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "4001",
           "Message" => "Invalid mobile number"
         }}
      end)

      params = %{
        amount: 1000,
        store_id: "store-test",
        order_reference: "ORD-005",
        description: "Test",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/return",
        channel: "mtn-gh"
      }

      assert {:error, error} = Hubtel.initiate_payment(params)
      assert error.code == "4001"
      assert error.message == "Invalid mobile number"
    end

    test "handles HTTP error" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, _opts ->
        {:error, %{status: 500, body: "Internal Server Error"}}
      end)

      params = %{
        amount: 1000,
        store_id: "store-test",
        order_reference: "ORD-006",
        description: "Test",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/return",
        channel: "mtn-gh"
      }

      assert {:error, _reason} = Hubtel.initiate_payment(params)
    end
  end

  describe "verify_payment/1" do
    test "returns payment status on success" do
      Emakola.HTTPClientMock
      |> expect(:get, fn url, _opts ->
        assert url =~ "/v2/payment/HUB-test-ref/status"

        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "Status" => "Paid",
             "Amount" => 50.00,
             "ClientReference" => "HUB-test-ref"
           }
         }}
      end)

      assert {:ok, result} = Hubtel.verify_payment("HUB-test-ref")
      assert result.status == "Paid"
      # 50.00 cedis -> 5000 pesewas
      assert result.amount == 5000
      assert result.reference == "HUB-test-ref"
    end

    test "converts cedis back to pesewas in response" do
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "Status" => "Paid",
             "Amount" => 123.45,
             "ClientReference" => "HUB-ref-123"
           }
         }}
      end)

      assert {:ok, result} = Hubtel.verify_payment("HUB-ref-123")
      # 123.45 cedis -> 12345 pesewas
      assert result.amount == 12345
    end

    test "handles failed verification" do
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "4010",
           "Message" => "Transaction not found"
         }}
      end)

      assert {:error, error} = Hubtel.verify_payment("HUB-nonexistent")
      assert error.code == "4010"
    end
  end

  describe "process_refund/2" do
    test "converts amount from pesewas to cedis correctly" do
      Emakola.HTTPClientMock
      |> expect(:post, fn url, opts ->
        assert url =~ "/v2/refund"
        body = Keyword.get(opts, :json)

        # 250000 pesewas -> 2500.00 cedis
        assert body["Amount"] == 2500.00
        assert body["ClientReference"] == "HUB-original-ref"

        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "RefundId" => "refund-abc-123",
             "Amount" => 2500.00
           }
         }}
      end)

      assert {:ok, result} = Hubtel.process_refund("HUB-original-ref", 250_000)
      assert result.refund_id == "refund-abc-123"
      # 2500.00 cedis -> 250000 pesewas
      assert result.amount == 250_000
    end

    test "handles refund error" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "4020",
           "Message" => "Insufficient funds for refund"
         }}
      end)

      assert {:error, error} = Hubtel.process_refund("HUB-ref", 100_000)
      assert error.code == "4020"
    end
  end

  describe "verify_webhook/2" do
    test "verifies webhook by calling status check API" do
      # Hubtel doesn't sign webhooks; we verify by checking payment status via API
      Emakola.HTTPClientMock
      |> expect(:get, fn url, _opts ->
        assert url =~ "/v2/payment/HUB-webhook-ref/status"

        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "Status" => "Paid",
             "Amount" => 100.00,
             "ClientReference" => "HUB-webhook-ref"
           }
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-webhook-ref"})
      assert :ok = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook when status check fails" do
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "4010",
           "Message" => "Transaction not found"
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-fake-ref"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook when HTTP call fails" do
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:error, %{status: 500, body: "Server error"}}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-error-ref"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end
  end
end
