defmodule Emakola.Notifications.ProviderLogSafetyTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mox

  alias Emakola.Notifications.Channels.{SMS, WhatsApp}
  alias Emakola.Notifications.Providers.{LogSMS, LogWhatsApp}

  @phone "+233244123456"
  @email "ama.boateng@example.com"
  @message "Reset code 998812 for ama.boateng@example.com"
  @token "provider-token-super-secret"

  setup :verify_on_exit!

  setup do
    previous_level = Logger.level()
    original_http = Application.get_env(:emakola, :http_client)
    original_sms = Application.get_env(:emakola, SMS)
    original_whatsapp = Application.get_env(:emakola, WhatsApp)

    Logger.configure(level: :info)

    Application.put_env(:emakola, SMS,
      api_key: @token,
      sender_id: "Makola",
      api_url: "https://sms.invalid/messages"
    )

    Application.put_env(:emakola, WhatsApp,
      api_token: @token,
      phone_number_id: "123456789"
    )

    on_exit(fn ->
      Logger.configure(level: previous_level)
      restore_env(:http_client, original_http)
      restore_env(SMS, original_sms)
      restore_env(WhatsApp, original_whatsapp)
    end)

    :ok
  end

  test "logging-only providers omit recipients, content, params, and options" do
    store_id = Ash.UUID.generate()

    log =
      capture_log(fn ->
        assert {:ok, _result} =
                 LogSMS.send_sms(@phone, @message,
                   store_id: store_id,
                   api_token: @token
                 )

        assert {:ok, _result} =
                 LogWhatsApp.send_message(
                   @phone,
                   "auth_code",
                   %{code: "998812", email: @email, access_token: @token},
                   store_id: store_id,
                   api_token: @token
                 )
      end)

    assert log =~ "+233****3456"
    assert log =~ "message_bytes="
    assert log =~ "parameter_count=3"
    refute_sensitive_values(log)
  end

  test "production API error logs omit untrusted response bodies" do
    Application.put_env(:emakola, :http_client, Emakola.HTTPClientMock)

    stub(Emakola.HTTPClientMock, :post, fn _url, _opts ->
      {:ok,
       %{
         status: 422,
         body: %{
           "detail" => "provider supplied private detail",
           "email" => @email,
           "phone" => @phone,
           "access_token" => @token,
           "code" => "998812"
         }
       }}
    end)

    log =
      capture_log(fn ->
        assert {:error, %{status: 422}} =
                 SMS.send_sms(@phone, @message, bypass_rate_limit: true)

        assert {:error, %{status: 422}} =
                 WhatsApp.send_message(
                   @phone,
                   "auth_code",
                   %{code: "998812"},
                   bypass_rate_limit: true
                 )
      end)

    assert log =~ "API error 422; provider response omitted"
    assert log =~ "+233****3456"
    refute_sensitive_values(log)
  end

  test "production transport error logs use only a coarse error type" do
    Application.put_env(:emakola, :http_client, Emakola.HTTPClientMock)

    stub(Emakola.HTTPClientMock, :post, fn _url, _opts ->
      {:error,
       %{
         detail: "provider supplied private detail",
         email: @email,
         phone: @phone,
         access_token: @token
       }}
    end)

    log =
      capture_log(fn ->
        assert {:error, _reason} = SMS.send_sms(@phone, @message, bypass_rate_limit: true)

        assert {:error, _reason} =
                 WhatsApp.send_message(
                   @phone,
                   "auth_code",
                   %{code: "998812"},
                   bypass_rate_limit: true
                 )
      end)

    assert log =~ "HTTP error type=unknown"
    refute_sensitive_values(log)
  end

  defp refute_sensitive_values(log) do
    refute log =~ @phone
    refute log =~ "233244123456"
    refute log =~ @email
    refute log =~ @message
    refute log =~ @token
    refute log =~ "998812"
    refute log =~ "provider supplied private detail"
  end

  defp restore_env(key, nil), do: Application.delete_env(:emakola, key)
  defp restore_env(key, value), do: Application.put_env(:emakola, key, value)
end
