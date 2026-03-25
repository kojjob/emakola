defmodule Emakola.Payments.Gateways.HubtelTest do
  use ExUnit.Case, async: true

  import Mox

  alias Emakola.Payments.Gateways.Hubtel

  setup :verify_on_exit!

  # -- initiate_payment/1 ---------------------------------------------------

  describe "initiate_payment/1" do
    test "returns authorization_url on success" do
      Emakola.Payments.HubtelClientMock
      |> expect(:create_invoice, fn params ->
        assert params["totalAmount"] == 5000.0
        assert params["description"] == "Order ORD-001"
        assert is_binary(params["clientReference"])
        assert String.starts_with?(params["clientReference"], "HUB-")

        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "checkoutUrl" => "https://pay.hubtel.com/checkout/abc123",
             "clientReference" => params["clientReference"]
           }
         }}
      end)

      params = %{
        amount: 500_000,
        store_id: "store-abc-123",
        order_reference: "ORD-001",
        description: "Order ORD-001",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/orders/ORD-001"
      }

      assert {:ok, result} = Hubtel.initiate_payment(params)
      assert result.authorization_url == "https://pay.hubtel.com/checkout/abc123"
      assert String.starts_with?(result.reference, "HUB-")
    end

    test "converts pesewas to cedis correctly (500000 pesewas -> 5000.0 cedis)" do
      Emakola.Payments.HubtelClientMock
      |> expect(:create_invoice, fn params ->
        assert params["totalAmount"] == 5000.0

        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "checkoutUrl" => "https://pay.hubtel.com/checkout/test",
             "clientReference" => params["clientReference"]
           }
         }}
      end)

      params = %{
        amount: 500_000,
        store_id: "store-def-456",
        order_reference: "ORD-002",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/orders/ORD-002"
      }

      assert {:ok, _result} = Hubtel.initiate_payment(params)
    end

    test "generates reference with HUB prefix and store_id" do
      Emakola.Payments.HubtelClientMock
      |> expect(:create_invoice, fn params ->
        ref = params["clientReference"]
        assert String.starts_with?(ref, "HUB-store1-")

        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "checkoutUrl" => "https://pay.hubtel.com/checkout/test",
             "clientReference" => ref
           }
         }}
      end)

      params = %{
        amount: 1000,
        store_id: "store123-def-456",
        order_reference: "ORD-004",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/return"
      }

      assert {:ok, _result} = Hubtel.initiate_payment(params)
    end

    test "returns error when Hubtel returns non-0000 response code" do
      Emakola.Payments.HubtelClientMock
      |> expect(:create_invoice, fn _params ->
        {:ok,
         %{
           "responseCode" => "4001",
           "message" => "Invalid request parameters"
         }}
      end)

      params = %{
        amount: 1000,
        store_id: "store-test",
        order_reference: "ORD-005",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/return"
      }

      assert {:error, {:hubtel_error, _message}} = Hubtel.initiate_payment(params)
    end

    test "returns gateway_error on network failure" do
      Emakola.Payments.HubtelClientMock
      |> expect(:create_invoice, fn _params ->
        {:error, :timeout}
      end)

      params = %{
        amount: 1000,
        store_id: "store-test",
        order_reference: "ORD-006",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/return"
      }

      assert {:error, {:gateway_error, :timeout}} = Hubtel.initiate_payment(params)
    end

    test "generates unique references for each call" do
      Emakola.Payments.HubtelClientMock
      |> expect(:create_invoice, 2, fn params ->
        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "checkoutUrl" => "https://pay.hubtel.com/checkout/test",
             "clientReference" => params["clientReference"]
           }
         }}
      end)

      params = %{
        amount: 1000,
        store_id: "store-unique-test",
        order_reference: "ORD-007",
        callback_url: "https://example.com/webhooks/hubtel",
        return_url: "https://example.com/return"
      }

      {:ok, result1} = Hubtel.initiate_payment(params)
      {:ok, result2} = Hubtel.initiate_payment(params)

      assert result1.reference != result2.reference
      assert result1.reference =~ ~r/^HUB-[a-z0-9-]+-\d+-[a-z0-9]+$/
    end
  end

  # -- verify_payment/1 ----------------------------------------------------

  describe "verify_payment/1" do
    test "returns payment details on successful verification" do
      reference = "HUB-test-ref-123"

      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn ref ->
        assert ref == reference

        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "paid",
             "totalAmount" => 50.0,
             "clientReference" => reference,
             "paymentChannel" => "mtn-gh"
           }
         }}
      end)

      assert {:ok, result} = Hubtel.verify_payment(reference)
      assert result.status == :paid
      assert result.amount == 5000
      assert result.reference == reference
      assert result.channel == "mtn-gh"
    end

    test "converts cedis back to pesewas in response" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "paid",
             "totalAmount" => 123.45,
             "clientReference" => "HUB-ref-123"
           }
         }}
      end)

      assert {:ok, result} = Hubtel.verify_payment("HUB-ref-123")
      assert result.amount == 12345
    end

    test "maps Hubtel status strings to atoms" do
      for {hubtel_status, expected_atom} <- [
            {"paid", :paid},
            {"Paid", :paid},
            {"completed", :completed},
            {"failed", :failed},
            {"pending", :pending},
            {"cancelled", :cancelled}
          ] do
        Emakola.Payments.HubtelClientMock
        |> expect(:check_invoice_status, fn _ref ->
          {:ok,
           %{
             "responseCode" => "0000",
             "data" => %{
               "invoiceStatus" => hubtel_status,
               "totalAmount" => 10.0,
               "clientReference" => "HUB-status-test"
             }
           }}
        end)

        assert {:ok, result} = Hubtel.verify_payment("HUB-status-test")
        assert result.status == expected_atom
      end
    end

    test "returns error on Hubtel API error response" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "4010",
           "message" => "Transaction not found"
         }}
      end)

      assert {:error, {:hubtel_error, _}} = Hubtel.verify_payment("HUB-nonexistent")
    end

    test "returns gateway_error on network failure" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:error, %{reason: :timeout}}
      end)

      assert {:error, {:gateway_error, _}} = Hubtel.verify_payment("some-ref")
    end
  end

  # -- process_refund/2 ----------------------------------------------------

  describe "process_refund/2" do
    test "returns :not_supported error (Hubtel refunds are manual)" do
      assert {:error, :not_supported} = Hubtel.process_refund("HUB-ref", 100_000)
    end
  end

  # -- verify_webhook/2 ----------------------------------------------------

  describe "verify_webhook/2" do
    test "verifies webhook by calling status check API" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn ref ->
        assert ref == "HUB-webhook-ref"

        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "paid",
             "totalAmount" => 100.0,
             "clientReference" => "HUB-webhook-ref"
           }
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-webhook-ref"})
      assert :ok = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook when status check returns non-paid status" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "failed",
             "totalAmount" => 100.0,
             "clientReference" => "HUB-failed-ref"
           }
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-failed-ref"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook when status check API fails" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "4010",
           "message" => "Transaction not found"
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-fake-ref"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook when HTTP call fails" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:error, %{status: 500, body: "Server error"}}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-error-ref"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook with invalid JSON body" do
      assert {:error, :invalid_signature} = Hubtel.verify_webhook("not json", %{})
    end

    test "rejects webhook without ClientReference" do
      body = Jason.encode!(%{"other" => "data"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end
  end
end
