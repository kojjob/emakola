defmodule Emakola.Notifications.Providers.LogSMS do
  @moduledoc """
  Logging-only SMS provider for development and testing.

  Logs the message via Logger.info and returns a success tuple.
  No real SMS is sent.
  """

  @behaviour Emakola.Notifications.SMSProvider

  require Logger

  @impl true
  def send_sms(to, message, opts \\ []) do
    Logger.info("[LogSMS] Sending SMS to #{to}: #{message} (opts: #{inspect(opts)})")
    {:ok, %{provider: :log, to: to, message: message}}
  end
end
