defmodule Emakola.Notifications.SMSProvider do
  @moduledoc """
  The single SMS behaviour. Workers and services resolve an implementation
  via `Application.get_env(:emakola, :sms_provider, LogSMS)` and call
  `send_sms/3`; `send_order_sms/2` is an optional convenience implemented by
  the full gateway channel (`Emakola.Notifications.Channels.SMS`).

  Implementations: `Channels.SMS` (real HTTP gateway — generic Bearer or
  Arkesel v2 via its `provider` config), `Providers.LogSMS` (dev logging
  stub), `Emakola.SMSProviderMock` (Mox, test).

  This consolidates the former `Channels.SMSBehaviour` — the two hierarchies
  duplicated the same contract with one extra convenience callback.
  """

  @callback send_sms(to :: String.t(), message :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback send_order_sms(order :: map(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @optional_callbacks send_order_sms: 2
end
