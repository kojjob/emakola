defmodule Emakola.Payments.Workers.HubtelWebhookHandlerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Mox

  alias Emakola.Payments.Workers.HubtelWebhookHandler

  setup :verify_on_exit!

  describe "perform/1" do
    test "verifies payment by calling Hubtel status check API" do
      Emakola.HTTPClientMock
      |> expect(:get, fn url, _opts ->
        assert url =~ "/v2/payment/HUB-order-001/status"

        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "Status" => "Paid",
             "Amount" => 50.00,
             "ClientReference" => "HUB-order-001"
           }
         }}
      end)

      args = %{
        "client_reference" => "HUB-order-001",
        "amount" => 50.00,
        "status" => "Success"
      }

      assert :ok = perform_job(HubtelWebhookHandler, args)
    end

    test "returns error when payment verification fails" do
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "4010",
           "Message" => "Transaction not found"
         }}
      end)

      args = %{
        "client_reference" => "HUB-fake-ref",
        "amount" => 50.00,
        "status" => "Success"
      }

      assert {:error, :verification_failed} = perform_job(HubtelWebhookHandler, args)
    end

    test "returns error when HTTP call fails" do
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:error, %{status: 500, body: "Server error"}}
      end)

      args = %{
        "client_reference" => "HUB-error-ref",
        "amount" => 50.00,
        "status" => "Success"
      }

      assert {:error, :verification_failed} = perform_job(HubtelWebhookHandler, args)
    end

    test "handles idempotent processing (same webhook twice)" do
      # First call - succeeds
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "Status" => "Paid",
             "Amount" => 100.00,
             "ClientReference" => "HUB-idempotent-001"
           }
         }}
      end)

      args = %{
        "client_reference" => "HUB-idempotent-001",
        "amount" => 100.00,
        "status" => "Success"
      }

      assert :ok = perform_job(HubtelWebhookHandler, args)

      # Second call with same reference - also succeeds (idempotent)
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:ok,
         %{
           "ResponseCode" => "0000",
           "Data" => %{
             "Status" => "Paid",
             "Amount" => 100.00,
             "ClientReference" => "HUB-idempotent-001"
           }
         }}
      end)

      assert :ok = perform_job(HubtelWebhookHandler, args)
    end
  end
end
