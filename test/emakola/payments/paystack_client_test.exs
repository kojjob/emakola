defmodule Emakola.Payments.PaystackClientTest do
  use ExUnit.Case, async: true

  import Mox

  alias Emakola.Payments.PaystackClient

  setup :verify_on_exit!

  describe "initialize_transaction/1" do
    test "posts to the correct URL with auth headers" do
      Emakola.HTTPClientMock
      |> expect(:post, fn url, opts ->
        assert url == "https://api.paystack.co/transaction/initialize"
        assert {"Authorization", "Bearer sk_test_default_secret"} in opts[:headers]
        assert {"Content-Type", "application/json"} in opts[:headers]

        body = opts[:json]
        assert body.amount == 500_000
        assert body.email == "customer@example.com"

        {:ok, %{"status" => true, "data" => %{"authorization_url" => "https://pay.test"}}}
      end)

      params = %{amount: 500_000, email: "customer@example.com", currency: "GHS"}
      assert {:ok, %{"status" => true}} = PaystackClient.initialize_transaction(params)
    end

    test "returns error tuple on HTTP failure" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, _opts ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = PaystackClient.initialize_transaction(%{amount: 100})
    end
  end

  describe "verify_transaction/1" do
    test "sends GET to the correct URL" do
      reference = "PAY-test-ref"

      Emakola.HTTPClientMock
      |> expect(:get, fn url, opts ->
        assert url == "https://api.paystack.co/transaction/verify/#{reference}"
        assert {"Authorization", "Bearer sk_test_default_secret"} in opts[:headers]

        {:ok,
         %{
           "status" => true,
           "data" => %{"status" => "success", "amount" => 500_000, "reference" => reference}
         }}
      end)

      assert {:ok, %{"status" => true}} = PaystackClient.verify_transaction(reference)
    end

    test "returns error on network failure" do
      Emakola.HTTPClientMock
      |> expect(:get, fn _url, _opts ->
        {:error, :econnrefused}
      end)

      assert {:error, :econnrefused} = PaystackClient.verify_transaction("ref")
    end
  end

  describe "create_refund/1" do
    test "posts refund request to the correct URL" do
      Emakola.HTTPClientMock
      |> expect(:post, fn url, opts ->
        assert url == "https://api.paystack.co/refund"
        assert {"Authorization", "Bearer sk_test_default_secret"} in opts[:headers]

        body = opts[:json]
        assert body.transaction == "PAY-ref-123"
        assert body.amount == 250_000

        {:ok,
         %{
           "status" => true,
           "data" => %{"amount" => 250_000, "status" => "processed"}
         }}
      end)

      params = %{transaction: "PAY-ref-123", amount: 250_000}
      assert {:ok, %{"status" => true}} = PaystackClient.create_refund(params)
    end

    test "returns error on failure" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, _opts ->
        {:error, %{status: 400, body: "bad request"}}
      end)

      assert {:error, _} = PaystackClient.create_refund(%{transaction: "ref", amount: 100})
    end
  end
end
