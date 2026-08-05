defmodule Emakola.Notifications.Providers.LogSMS do
  @moduledoc """
  Logging-only SMS provider for development and testing.

  Logs a redacted delivery summary and returns a success tuple.
  No real SMS is sent.
  """

  @behaviour Emakola.Notifications.SMSProvider

  alias Emakola.Privacy

  require Logger

  @impl true
  def send_sms(to, message, opts \\ []) do
    Logger.info(
      "[LogSMS] Simulated SMS delivery to #{Privacy.mask_phone(to)} " <>
        "message_bytes=#{message |> to_string() |> byte_size()} " <>
        "store=#{Privacy.safe_uuid(Keyword.get(opts, :store_id))}"
    )

    {:ok, %{provider: :log, to: to, message: message}}
  end
end
