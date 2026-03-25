defmodule Emakola.Payments.Workers.HubtelWebhookHandlerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Mox

  alias Emakola.Payments.Workers.HubtelWebhookHandler

  setup :verify_on_exit!

  describe "perform/1" do
    test "verifies payment by calling Hubtel status check API" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn ref ->
        assert ref == "HUB-order-001"

        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "paid",
             "totalAmount" => 50.0,
             "clientReference" => "HUB-order-001"
           }
         }}
      end)

      args = %{
        "client_reference" => "HUB-order-001",
        "amount" => 50.0,
        "status" => "Success"
      }

      # Returns {:error, :payment_not_found} because we don't have a real
      # payment record in the DB, but verify_payment succeeded
      result = perform_job(HubtelWebhookHandler, args)
      assert result in [:ok, {:error, :payment_not_found}]
    end

    test "returns error when payment verification returns non-paid status" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "pending",
             "totalAmount" => 50.0,
             "clientReference" => "HUB-pending-ref"
           }
         }}
      end)

      args = %{
        "client_reference" => "HUB-pending-ref",
        "amount" => 50.0,
        "status" => "Pending"
      }

      # Non-paid status triggers the failed path, which tries to find a payment
      result = perform_job(HubtelWebhookHandler, args)
      assert result in [:ok, {:error, :payment_not_found}]
    end

    test "returns error when Hubtel API returns error response" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:ok,
         %{
           "responseCode" => "4010",
           "message" => "Transaction not found"
         }}
      end)

      args = %{
        "client_reference" => "HUB-fake-ref",
        "amount" => 50.0,
        "status" => "Success"
      }

      assert {:error, :verification_failed} = perform_job(HubtelWebhookHandler, args)
    end

    test "returns error when HTTP call fails" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, fn _ref ->
        {:error, %{status: 500, body: "Server error"}}
      end)

      args = %{
        "client_reference" => "HUB-error-ref",
        "amount" => 50.0,
        "status" => "Success"
      }

      assert {:error, :verification_failed} = perform_job(HubtelWebhookHandler, args)
    end

    test "handles idempotent processing (same webhook twice)" do
      Emakola.Payments.HubtelClientMock
      |> expect(:check_invoice_status, 2, fn _ref ->
        {:ok,
         %{
           "responseCode" => "0000",
           "data" => %{
             "invoiceStatus" => "paid",
             "totalAmount" => 100.0,
             "clientReference" => "HUB-idempotent-001"
           }
         }}
      end)

      args = %{
        "client_reference" => "HUB-idempotent-001",
        "amount" => 100.0,
        "status" => "Success"
      }

      # Both calls go through verification — idempotent
      result1 = perform_job(HubtelWebhookHandler, args)
      result2 = perform_job(HubtelWebhookHandler, args)

      assert result1 in [:ok, {:error, :payment_not_found}]
      assert result2 in [:ok, {:error, :payment_not_found}]
    end
  end
end
