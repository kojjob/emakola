defmodule Emakola.Notifications.Channels.SMSTest do
  use ExUnit.Case, async: false

  alias Emakola.Notifications.Channels.SMS

  # ── Test data helpers ──────────────────────────────────────────

  defp build_order(attrs \\ []) do
    Map.merge(
      %{
        order_number: "ORD-20260325-SMS01",
        total: 50_000,
        currency: "GHS",
        store_id: Ash.UUID.generate()
      },
      Map.new(attrs)
    )
  end

  # ── build_sms_payload/2 ────────────────────────────────────────

  describe "build_sms_payload/2" do
    test "builds correct payload structure" do
      payload = SMS.build_sms_payload("+233244123456", "Hello there!")

      assert payload.from == "Emakola"
      assert payload.to == "+233244123456"
      assert payload.content == "Hello there!"
    end

    test "preserves + in phone number" do
      payload = SMS.build_sms_payload("+233244123456", "test")
      assert payload.to == "+233244123456"
    end

    test "strips invalid characters from phone number" do
      payload = SMS.build_sms_payload("+233 (244) 123-456", "test")
      assert payload.to == "+233244123456"
    end
  end

  # ── send_sms/3 ────────────────────────────────────────────────

  describe "send_sms/3 with mocked HTTP" do
    setup do
      original_http = Application.get_env(:emakola, :http_client)
      original_sms = Application.get_env(:emakola, Emakola.Notifications.Channels.SMS)

      Application.put_env(:emakola, :http_client, __MODULE__.MockHTTP)

      Application.put_env(:emakola, Emakola.Notifications.Channels.SMS,
        api_key: "test_sms_key",
        sender_id: "TestShop",
        api_url: "https://api.test-sms.example.com/v1/messages"
      )

      on_exit(fn ->
        if original_http,
          do: Application.put_env(:emakola, :http_client, original_http),
          else: Application.delete_env(:emakola, :http_client)

        if original_sms,
          do: Application.put_env(:emakola, Emakola.Notifications.Channels.SMS, original_sms),
          else: Application.delete_env(:emakola, Emakola.Notifications.Channels.SMS)
      end)

      :ok
    end

    test "sends SMS and returns success" do
      assert {:ok, result} = SMS.send_sms("+233244123456", "Your order is ready!")
      assert result.status == 200
      assert result.to == "+233244123456"
    end

    test "sends order SMS with formatted message" do
      order = build_order()

      assert {:ok, result} =
               SMS.send_order_sms(order,
                 customer_phone: "+233244123456",
                 store_name: "Accra Fashion Hub"
               )

      assert result.status == 200
    end
  end

  # ── send_order_sms/2 ──────────────────────────────────────────

  describe "send_order_sms/2 message formatting" do
    test "requires customer_phone option" do
      order = build_order()

      assert_raise KeyError, ~r/customer_phone/, fn ->
        SMS.send_order_sms(order, [])
      end
    end
  end

  # ── Error handling ─────────────────────────────────────────────

  describe "send_sms/3 error handling" do
    setup do
      original_http = Application.get_env(:emakola, :http_client)
      Application.put_env(:emakola, :http_client, __MODULE__.ErrorHTTP)

      on_exit(fn ->
        if original_http,
          do: Application.put_env(:emakola, :http_client, original_http),
          else: Application.delete_env(:emakola, :http_client)
      end)

      :ok
    end

    test "returns error on API failure" do
      assert {:error, %{status: 401}} = SMS.send_sms("+233244123456", "test")
    end
  end

  # Mock HTTP clients
  defmodule MockHTTP do
    def post(_url, _opts) do
      {:ok,
       %{
         status: 200,
         body: %{"message_id" => "sms_test_123", "status" => "queued"}
       }}
    end
  end

  defmodule ErrorHTTP do
    def post(_url, _opts) do
      {:ok,
       %{
         status: 401,
         body: %{"error" => "Invalid API key"}
       }}
    end
  end
end
