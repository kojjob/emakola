defmodule Emakola.Accounts.Senders.MagicLinkSender do
  @moduledoc "Sends magic link emails via Swoosh."
  use AshAuthentication.Sender
  alias Emakola.Privacy
  require Logger

  @impl true
  def send(user_or_email, token, _opts) do
    email =
      case user_or_email do
        %{email: email} -> to_string(email)
        email when is_binary(email) -> email
        other -> to_string(other)
      end

    Logger.info("Sending magic link to #{Privacy.mask_email(email)}")
    Emakola.Notifications.AuthMailer.magic_link(email, token)
    :ok
  end
end
