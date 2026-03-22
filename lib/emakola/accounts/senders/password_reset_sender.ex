defmodule Emakola.Accounts.Senders.PasswordResetSender do
  @moduledoc "Sends password reset emails via Swoosh."
  use AshAuthentication.Sender
  require Logger

  @impl true
  def send(user, token, _opts) do
    email =
      case user do
        %{email: email} -> to_string(email)
        email -> to_string(email)
      end

    Logger.info("Sending password reset to #{email}")

    if is_map(user) and Map.has_key?(user, :email) do
      # Ensure email is a plain string for Swoosh compatibility (Ash uses CiString)
      normalized_user = Map.update!(user, :email, &to_string/1)
      Emakola.Notifications.AuthMailer.password_reset(normalized_user, token)
    end

    :ok
  end
end
