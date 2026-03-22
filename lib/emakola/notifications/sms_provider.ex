defmodule Emakola.Notifications.SMSProvider do
  @moduledoc """
  Behaviour for SMS delivery providers.

  Implementations must handle sending a text message to a phone number.
  Real providers (e.g. Twilio, Africa's Talking) will be plugged in later;
  a logging stub is used in dev/test.
  """

  @callback send_sms(to :: String.t(), message :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
