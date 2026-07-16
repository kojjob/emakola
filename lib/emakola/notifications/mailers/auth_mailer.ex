defmodule Emakola.Notifications.AuthMailer do
  @moduledoc "Auth-related transactional emails."
  import Swoosh.Email

  alias Emakola.Mailer

  def welcome(user) do
    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(Mailer.from_address("Makola"))
    |> subject("Welcome to Makola!")
    |> html_body("""
    <h1>Welcome to Makola!</h1>
    <p>Hi #{user.name || "there"},</p>
    <p>Your account has been created. Get started by creating your first workspace.</p>
    """)
    |> text_body("Welcome to Makola! Your account has been created.")
    |> Mailer.deliver()
  end

  # The link lands on the interactive confirm page (require_interaction? — a GET
  # from an email-scanner bot must not be able to confirm; the page POSTs).
  def confirm_email(email, token) do
    url = "#{EmakolaWeb.Endpoint.url()}/confirm/merchant?confirm=#{token}"

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
    <p>Click the link below to reset your password. This link expires in 1 hour.</p>
    <a href="#{url}">Reset Password</a>
    """)
    |> text_body("Reset your password: #{url}")
    |> Mailer.deliver()
  end
end
