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

      assert payload.from == "Makola"
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

  # ── Arkesel provider mode (SMS_PROVIDER=arkesel) ───────────────

  describe "arkesel provider mode" do
    setup do
      original_http = Application.get_env(:emakola, :http_client)
      original_sms = Application.get_env(:emakola, Emakola.Notifications.Channels.SMS)

      Application.put_env(:emakola, :http_client, __MODULE__.CaptureHTTP)

      Application.put_env(:emakola, Emakola.Notifications.Channels.SMS,
        provider: :arkesel,
        api_key: "ARKESEL_KEY_123",
        sender_id: "Makola"
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

    test "builds the Arkesel v2 payload shape" do
      payload = SMS.build_sms_payload("+233 244 123 456", "Hello!")

      assert payload == %{
               sender: "Makola",
               message: "Hello!",
               recipients: ["+233244123456"]
             }
    end

    test "authenticates with the api-key header and Arkesel default URL" do
      assert {:ok, _} = SMS.send_sms("+233244123456", "hi", bypass_rate_limit: true)

      assert_received {:sms_post, url, headers, payload}
      assert url == "https://sms.arkesel.com/api/v2/sms/send"
      assert {"api-key", "ARKESEL_KEY_123"} in headers
      refute Enum.any?(headers, fn {name, _} -> name == "authorization" end)
      assert payload.recipients == ["+233244123456"]
    end

    test "an explicit SMS_API_URL still wins over the Arkesel default" do
      Application.put_env(:emakola, Emakola.Notifications.Channels.SMS,
        provider: :arkesel,
        api_key: "ARKESEL_KEY_123",
        api_url: "https://custom.example.com/send"
      )

      assert {:ok, _} = SMS.send_sms("+233244123456", "hi", bypass_rate_limit: true)
      assert_received {:sms_post, "https://custom.example.com/send", _headers, _payload}
    end
  end

  test "the channel implements the consolidated SMSProvider behaviour" do
    behaviours =
      Emakola.Notifications.Channels.SMS.module_info(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    assert Emakola.Notifications.SMSProvider in behaviours
  end

  defmodule CaptureHTTP do
    def post(url, opts) do
      send(self(), {:sms_post, url, opts[:headers], opts[:json]})
      {:ok, %{status: 200, body: %{"status" => "success"}}}
    end
  end
end
