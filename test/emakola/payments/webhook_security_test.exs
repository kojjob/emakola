defmodule Emakola.Payments.WebhookSecurityTest do
  @moduledoc """
  Tests for webhook HMAC signature verification across payment gateways.

  Covers:
  - Paystack HMAC-SHA512 signature validation
  - Hubtel webhook verification via status check API
  - Tampered payload detection
  - Missing/malformed signature handling
  """

  use ExUnit.Case, async: true

  import Mox

  alias Emakola.Payments.Gateways.Paystack
  alias Emakola.Payments.Gateways.Hubtel

  setup :verify_on_exit!

  @paystack_secret "sk_test_default_secret"

  defp compute_paystack_signature(body) do
    :crypto.mac(:hmac, :sha512, @paystack_secret, body)
    |> Base.encode16(case: :lower)
  end

  # ── Paystack Webhook Signature ─────────────────────────────────────

  describe "Paystack verify_webhook/2 — valid signatures" do
    test "accepts a correctly signed charge.success payload" do
      body = ~s({"event":"charge.success","data":{"reference":"PAY-abc-123","amount":500000}})
      signature = compute_paystack_signature(body)
      headers = %{"x-paystack-signature" => signature}

      assert :ok = Paystack.verify_webhook(body, headers)
    end

    test "accepts a correctly signed refund.processed payload" do
      body =
        Jason.encode!(%{
          "event" => "refund.processed",
          "data" => %{
            "transaction" => %{"reference" => "PAY-ref-456"},
            "amount" => 250_000
          }
        })

      signature = compute_paystack_signature(body)
      headers = %{"x-paystack-signature" => signature}

      assert :ok = Paystack.verify_webhook(body, headers)
    end

    test "accepts signature for empty JSON object body" do
      body = "{}"
      signature = compute_paystack_signature(body)
      headers = %{"x-paystack-signature" => signature}

      assert :ok = Paystack.verify_webhook(body, headers)
    end
  end

  describe "Paystack verify_webhook/2 — invalid signatures" do
    test "rejects an incorrect signature" do
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})
      headers = %{"x-paystack-signature" => "deadbeef0123456789abcdef"}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(body, headers)
    end

    test "rejects a signature computed with the wrong secret key" do
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})

      wrong_signature =
        :crypto.mac(:hmac, :sha512, "wrong_secret_key", body)
        |> Base.encode16(case: :lower)

      headers = %{"x-paystack-signature" => wrong_signature}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(body, headers)
    end

    test "rejects when signature header is missing entirely" do
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})
      headers = %{}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(body, headers)
    end

    test "rejects when signature header is nil" do
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})
      headers = %{"x-paystack-signature" => nil}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(body, headers)
    end

    test "rejects tampered payload — original signature does not match modified body" do
      original_body =
        Jason.encode!(%{
          "event" => "charge.success",
          "data" => %{"reference" => "PAY-legit-ref", "amount" => 500_000}
        })

      signature = compute_paystack_signature(original_body)

      # Attacker tampers with the amount
      tampered_body =
        Jason.encode!(%{
          "event" => "charge.success",
          "data" => %{"reference" => "PAY-legit-ref", "amount" => 99_999_999}
        })

      headers = %{"x-paystack-signature" => signature}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(tampered_body, headers)
    end

    test "rejects tampered payload — single byte change in body" do
      body = ~s({"event":"charge.success","data":{"reference":"PAY-ref"}})
      signature = compute_paystack_signature(body)

      # Change one character
      tampered = ~s({"event":"charge.success","data":{"reference":"PAY-ref"}})
      tampered = String.replace(tampered, "PAY-ref", "PAY-rex")

      headers = %{"x-paystack-signature" => signature}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(tampered, headers)
    end

    test "rejects empty string signature" do
      body = ~s({"event":"charge.success"})
      headers = %{"x-paystack-signature" => ""}

      assert {:error, :invalid_signature} = Paystack.verify_webhook(body, headers)
    end
  end

  describe "Paystack signature — timing-safe comparison" do
    test "uses constant-time comparison (Plug.Crypto.secure_compare)" do
      # This test verifies the correct signature is accepted — the timing-safe
      # comparison is an implementation detail (Plug.Crypto.secure_compare),
      # but we verify the functional outcome: valid sig passes, near-miss fails.
      body = ~s({"event":"charge.success","data":{"amount":1000}})
      valid_sig = compute_paystack_signature(body)

      # Valid signature passes
      assert :ok = Paystack.verify_webhook(body, %{"x-paystack-signature" => valid_sig})

      # Off-by-one character in signature fails
      near_miss = String.slice(valid_sig, 0..-2//1) <> "0"

      assert {:error, :invalid_signature} =
               Paystack.verify_webhook(body, %{"x-paystack-signature" => near_miss})
    end
  end

  # ── Hubtel Webhook Verification ────────────────────────────────────

  describe "Hubtel verify_webhook/2 — valid webhooks" do
    test "accepts webhook when status check confirms paid" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn ref ->
        assert ref == "HUB-valid-ref"

        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "paid",
             "totalAmount" => 100.00,
             "clientReference" => "HUB-valid-ref"
           }
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-valid-ref"})
      assert :ok = Hubtel.verify_webhook(body, %{})
    end

    test "accepts webhook when status check confirms completed" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "completed",
             "totalAmount" => 50.00,
             "clientReference" => "HUB-success-ref"
           }
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-success-ref"})
      assert :ok = Hubtel.verify_webhook(body, %{})
    end
  end

  describe "Hubtel verify_webhook/2 — invalid webhooks" do
    test "rejects webhook when status check returns non-paid status" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "pending",
             "totalAmount" => 100.00,
             "clientReference" => "HUB-pending-ref"
           }
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-pending-ref"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook when status check API returns error response code" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "4010",
           "message" => "Transaction not found"
         }}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-nonexistent"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook when HTTP call to status API fails" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:error, %{status: 500, body: "Internal server error"}}
      end)

      body = Jason.encode!(%{"ClientReference" => "HUB-http-error"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook with missing ClientReference field" do
      body = Jason.encode!(%{"Amount" => 100.00, "Status" => "Paid"})
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook with invalid JSON body" do
      body = "not-json-at-all"
      assert {:error, :invalid_signature} = Hubtel.verify_webhook(body, %{})
    end

    test "rejects webhook with empty body" do
      assert {:error, :invalid_signature} = Hubtel.verify_webhook("", %{})
    end
  end
end
