defmodule Emakola.Notifications.WhatsAppProvider do
  @moduledoc """
  Behaviour for WhatsApp message delivery providers.

  Implementations must handle sending a templated WhatsApp message.
  A logging stub is used in dev/test; the real WhatsApp Business API
  provider will be plugged in later.
  """

  @callback send_message(
              to :: String.t(),
              template :: String.t(),
              params :: map(),
              opts :: keyword()
            ) ::
              {:ok, map()} | {:error, term()}
end
