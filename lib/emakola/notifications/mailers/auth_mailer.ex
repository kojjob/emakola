defmodule Emakola.Notifications.AuthMailer do
  @moduledoc "Auth-related transactional emails."
  import Swoosh.Email

  alias Emakola.Mailer

  # The link lands on the interactive confirm page (require_interaction? — a GET
  # from an email-scanner bot must not be able to confirm; the page POSTs).
  def confirm_email(email, token) do
    # Our page, not the strategy route: the framework's generated interaction
    # page omits a CSRF token, so submitting it raises and the account is
    # never confirmed. Ours posts to the same action with a valid token.
    url = "#{EmakolaWeb.Endpoint.url()}/auth/confirm?confirm=#{token}"

    new()
    |> to(email)
    |> from(Mailer.from_address("Makola"))
    |> subject("Confirm your Makola email")
    |> html_body("""
    <h2>Confirm your email</h2>
    <p>Click the button on the next page to confirm this address for your Makola account.</p>
    <a href="#{url}">Confirm my email</a>
    <p>If you didn't create a Makola account, ignore this email.</p>
    """)
    |> text_body("Confirm your Makola email: #{url}")
    |> Mailer.deliver()
  end

  def magic_link(email, token) do
    url = "#{EmakolaWeb.Endpoint.url()}/auth/magic-link?token=#{token}"

    new()
    |> to(email)
    |> from(Mailer.from_address("Makola"))
    |> subject("Your Makola sign-in link")
    |> html_body("""
    <h2>Sign in to Makola</h2>
    <p>Click the link below to sign in. This link expires in 10 minutes.</p>
    <a href="#{url}">Sign in to Makola</a>
    """)
    |> text_body("Sign in to Makola: #{url}")
    |> Mailer.deliver()
  end

  def password_reset(user, token) do
    url = "#{EmakolaWeb.Endpoint.url()}/auth/reset-password?token=#{token}"

    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(Mailer.from_address("Makola"))
    |> subject("Reset your Makola password")
    |> html_body("""
    <h2>Password Reset</h2>
    <p>Click the link below to reset your password. This link expires in 24 hours.</p>
    <a href="#{url}">Reset Password</a>
    """)
    |> text_body("Reset your password: #{url}")
    |> Mailer.deliver()
  end
end
