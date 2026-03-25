defmodule Emakola.Notifications.Channels.SMSBehaviour do
  @moduledoc """
  Behaviour for SMS delivery via an external gateway API.

  Defines the contract for sending SMS messages. Higher-level than
  `Emakola.Notifications.SMSProvider` — includes order-specific
  convenience methods alongside the generic send.
  """

  @type phone :: String.t()
  @type message :: String.t()
  @type order :: map()
  @type opts :: keyword()
  @type success :: {:ok, map()}
  @type error :: {:error, term()}

  @doc "Send a generic SMS message to a phone number."
  @callback send_sms(phone(), message(), opts()) :: success() | error()

  @doc "Send a formatted order confirmation SMS."
  @callback send_order_sms(order(), opts()) :: success() | error()
end
