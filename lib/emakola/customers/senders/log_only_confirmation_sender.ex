defmodule Emakola.Customers.Senders.LogOnlyConfirmationSender do
  @moduledoc """
  Placeholder sender for the customer confirmation add-on.

  Customers have no confirmation email flow yet (it needs per-store branding
  and a store-scoped confirm URL), and the add-on is configured with
  `confirm_on_create?(false)`, so this sender should never fire in normal
  operation — it exists because the DSL requires one. If it DOES fire, log
  loudly rather than crash the calling action.
  """
  use AshAuthentication.Sender
  require Logger

  @impl true
  def send(user_or_email, _token, _opts) do
    Logger.warning(
      "LogOnlyConfirmationSender invoked for #{inspect(user_or_email, limit: 1)} — " <>
        "customer confirmation email flow is not built; no email was sent"
    )

    :ok
  end
end
