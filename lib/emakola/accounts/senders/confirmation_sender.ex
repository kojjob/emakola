defmodule Emakola.Accounts.Senders.ConfirmationSender do
  @moduledoc """
  Emails a merchant their email-confirmation link.

  Failure-tolerant on purpose: registration must NEVER fail because an email
  could not be sent — production ran on placeholder mail credentials for
  weeks, and a merchant locked out of signing up because Resend rejected a
  dummy key would be strictly worse than an unconfirmed account. An
  unconfirmed account is safe by construction: `prevent_hijacking?` refuses
  OAuth upserts over it, and sign-in is not gated on confirmation.
  """
  use AshAuthentication.Sender
  require Logger

  @impl true
  def send(user_or_email, token, _opts) do
    email =
      case user_or_email do
        %{email: email} -> to_string(email)
        email when is_binary(email) -> email
        other -> to_string(other)
      end

    Logger.info("Sending email confirmation to #{email}")
    Emakola.Notifications.AuthMailer.confirm_email(email, token)
    :ok
  rescue
    error ->
      Logger.error("Email confirmation send failed for merchant: #{Exception.message(error)}")
      :ok
  end
end
