defmodule Emakola.Notifications.Providers.LogPush do
  @moduledoc "Dev/no-op push provider — logs instead of calling FCM. Token is truncated to avoid leaking credentials into logs."

  @behaviour Emakola.Notifications.PushProvider

  require Logger

  @impl true
  def send_push(device_token, %{title: title, body: body}) do
    Logger.warning(
      "[push] (log provider) to #{String.slice(device_token, 0, 8)}…: #{title} — #{body}"
    )

    {:ok, %{provider: :log}}
  end
end
