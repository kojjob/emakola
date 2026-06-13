defmodule Emakola.Notifications.PushProvider do
  @moduledoc """
  Behaviour for mobile push delivery (FCM). Implementations:

    * `Emakola.Notifications.Providers.FcmPush` — production (FCM HTTP v1 via Req + Goth)
    * `Emakola.Notifications.Providers.LogPush` — dev default (logs only)
    * `Emakola.PushProviderMock` — test (Mox)

  Resolved at runtime from `config :emakola, :push_provider`.
  """

  @type notification :: %{title: String.t(), body: String.t(), data: map()}

  @callback send_push(device_token :: String.t(), notification()) ::
              {:ok, map()} | {:error, :unregistered} | {:error, term()}
end
