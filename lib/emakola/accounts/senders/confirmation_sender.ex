defmodule Emakola.Accounts.Senders.ConfirmationSender do
  @moduledoc """
  Emails a merchant their email-confirmation link.

  Failure-tolerant on purpose: registration must NEVER fail because an email
  could not be sent. That tolerance means something different now — sign-in
  IS gated on confirmation, so a send that quietly fails leaves a merchant
  registered and unable to get in, rather than merely unconfirmed.

  Registration still succeeds, because the alternative is losing the account
  entirely, and there are two ways back: the resend button on /auth/verify,
  and `mix emakola.confirm_merchant` when mail delivery itself is the problem.
  Production once ran three weeks on a deleted key without anyone noticing;
  check the provider's own last-used timestamp, not this module's `:ok`.
  """
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

    Logger.info("Sending email confirmation to #{Privacy.mask_email(email)}")
    Emakola.Notifications.AuthMailer.confirm_email(email, token)
    :ok
  rescue
    error ->
      Logger.error("Email confirmation send failed type=#{Privacy.error_type(error)}")
      :ok
  end
end
