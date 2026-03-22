defmodule Emakola.Notifications.Providers.LogWhatsApp do
  @moduledoc """
  Logging-only WhatsApp provider for development and testing.

  Logs the message via Logger.info and returns a success tuple.
  No real WhatsApp message is sent.
  """

  @behaviour Emakola.Notifications.WhatsAppProvider

  require Logger

  @impl true
  def send_message(to, template, params, opts \\ []) do
    Logger.info(
      "[LogWhatsApp] Sending WhatsApp to #{to}: template=#{template}, params=#{inspect(params)} (opts: #{inspect(opts)})"
    )

    {:ok, %{provider: :log, to: to, template: template, params: params}}
  end
end
