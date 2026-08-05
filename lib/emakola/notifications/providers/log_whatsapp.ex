defmodule Emakola.Notifications.Providers.LogWhatsApp do
  @moduledoc """
  Logging-only WhatsApp provider for development and testing.

  Logs a redacted delivery summary and returns a success tuple.
  No real WhatsApp message is sent.
  """

  @behaviour Emakola.Notifications.WhatsAppProvider

  alias Emakola.Privacy

  require Logger

  @impl true
  def send_message(to, template, params, opts \\ []) do
    Logger.info(
      "[LogWhatsApp] Simulated WhatsApp delivery to #{Privacy.mask_phone(to)} " <>
        "template=#{Privacy.safe_label(template)} parameter_count=#{map_size(params)} " <>
        "store=#{Privacy.safe_uuid(Keyword.get(opts, :store_id))}"
    )

    {:ok, %{provider: :log, to: to, template: template, params: params}}
  end
end
