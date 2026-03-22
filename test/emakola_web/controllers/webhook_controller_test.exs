defmodule EmakolaWeb.WebhookControllerTest do
  use EmakolaWeb.ConnCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Payments.Workers.PaystackWebhookHandler

  setup do
    Application.put_env(:emakola, :paystack_secret_key, "sk_test_webhook_secret")

    on_exit(fn ->
      Application.delete_env(:emakola, :paystack_secret_key)
    end)

    :ok
  end

  describe "POST /webhooks/paystack" do
    test "enqueues job with valid signature", %{conn: conn} do
      body =
        Jason.encode!(%{
          "event" => "charge.success",
          "data" => %{
            "reference" => "PAY-test-ref",
            "amount" => 500_000,
            "status" => "success"
          }
        })

      signature =
        :crypto.mac(:hmac, :sha512, "sk_test_webhook_secret", body)
        |> Base.encode16(case: :lower)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-paystack-signature", signature)
        |> post("/webhooks/paystack", body)

      assert json_response(conn, 200)["status"] == "ok"

      assert_enqueued(worker: PaystackWebhookHandler)
    end

    test "returns 401 with invalid signature", %{conn: conn} do
      body =
        Jason.encode!(%{
          "event" => "charge.success",
          "data" => %{"reference" => "PAY-test-ref"}
        })

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-paystack-signature", "invalid_signature")
        |> post("/webhooks/paystack", body)

      assert json_response(conn, 401)["error"] == "invalid_signature"

      refute_enqueued(worker: PaystackWebhookHandler)
    end

    test "returns 401 with missing signature", %{conn: conn} do
      body =
        Jason.encode!(%{
          "event" => "charge.success",
          "data" => %{"reference" => "PAY-test-ref"}
        })

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/paystack", body)

      assert json_response(conn, 401)["error"] == "invalid_signature"
    end
  end
end
