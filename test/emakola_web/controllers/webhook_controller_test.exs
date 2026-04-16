defmodule EmakolaWeb.WebhookControllerTest do
  use EmakolaWeb.ConnCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Payments.Workers.HubtelWebhookHandler
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  @secret "sk_test_default_secret"

  defp sign_body(body) do
    :crypto.mac(:hmac, :sha512, @secret, body)
    |> Base.encode16(case: :lower)
  end

  defp hubtel_body do
    Jason.encode!(%{
      "ResponseCode" => "0000",
      "Data" => %{
        "ClientReference" => "PAY-integration-test",
        "Amount" => 500_000,
        "Status" => "Success"
      }
    })
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

      signature = sign_body(body)

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

  # ── POST /webhooks/hubtel — IP allowlist enforcement ─────────────
  #
  # These tests toggle the HubtelAllowlist plug flags per-test. The
  # global test.exs config sets the bypass flag to true, so we have to
  # turn it off here to actually exercise the security path.

  describe "POST /webhooks/hubtel" do
    setup do
      original_rules = Application.get_env(:emakola, :hubtel_webhook_allowlist)
      original_bypass = Application.get_env(:emakola, :hubtel_webhook_allowlist_disabled)

      on_exit(fn ->
        Application.put_env(:emakola, :hubtel_webhook_allowlist, original_rules || [])
        Application.put_env(:emakola, :hubtel_webhook_allowlist_disabled, original_bypass || true)
      end)

      :ok
    end

    test "enqueues job when remote_ip is in allowlist", %{conn: conn} do
      Application.put_env(:emakola, :hubtel_webhook_allowlist, ["127.0.0.1", "10.0.0.0/8"])
      Application.put_env(:emakola, :hubtel_webhook_allowlist_disabled, false)

      conn =
        conn
        |> Map.put(:remote_ip, {127, 0, 0, 1})
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/hubtel", hubtel_body())

      assert json_response(conn, 200)["status"] == "ok"
      assert_enqueued(worker: HubtelWebhookHandler)
    end

    test "returns 403 when remote_ip is not in allowlist", %{conn: conn} do
      Application.put_env(:emakola, :hubtel_webhook_allowlist, ["203.0.113.5"])
      Application.put_env(:emakola, :hubtel_webhook_allowlist_disabled, false)

      import ExUnit.CaptureLog

      capture_log(fn ->
        conn =
          conn
          |> Map.put(:remote_ip, {1, 2, 3, 4})
          |> put_req_header("content-type", "application/json")
          |> post("/webhooks/hubtel", hubtel_body())

        assert conn.status == 403
        assert json_response(conn, 403)["error"] == "forbidden"
        refute_enqueued(worker: HubtelWebhookHandler)
      end)
    end

    test "fail-closed: empty allowlist rejects request", %{conn: conn} do
      Application.put_env(:emakola, :hubtel_webhook_allowlist, [])
      Application.put_env(:emakola, :hubtel_webhook_allowlist_disabled, false)

      import ExUnit.CaptureLog

      capture_log(fn ->
        conn =
          conn
          |> Map.put(:remote_ip, {127, 0, 0, 1})
          |> put_req_header("content-type", "application/json")
          |> post("/webhooks/hubtel", hubtel_body())

        assert conn.status == 403
        refute_enqueued(worker: HubtelWebhookHandler)
      end)
    end

    test "bypass flag allows any IP through", %{conn: conn} do
      Application.put_env(:emakola, :hubtel_webhook_allowlist, [])
      Application.put_env(:emakola, :hubtel_webhook_allowlist_disabled, true)

      conn =
        conn
        |> Map.put(:remote_ip, {1, 2, 3, 4})
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/hubtel", hubtel_body())

      assert json_response(conn, 200)["status"] == "ok"
      assert_enqueued(worker: HubtelWebhookHandler)
    end
  end
end
