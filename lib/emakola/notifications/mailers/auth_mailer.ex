defmodule Emakola.Notifications.AuthMailer do
  @moduledoc "Auth-related transactional emails."
  import Swoosh.Email

  alias Emakola.Mailer

  def welcome(user) do
    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(Mailer.from_address("Emakola"))
    |> subject("Welcome to Emakola!")
    |> html_body("""
    <h1>Welcome to Emakola!</h1>
    <p>Hi #{user.name || "there"},</p>
    <p>Your account has been created. Get started by creating your first workspace.</p>
    """)
    |> text_body("Welcome to Emakola! Your account has been created.")
    |> Mailer.deliver()
  end

  def magic_link(email, token) do
    url = "#{EmakolaWeb.Endpoint.url()}/auth/magic-link?token=#{token}"

    new()
    |> to(email)
    |> from(Mailer.from_address("Emakola"))
    |> subject("Your Emakola sign-in link")
    |> html_body("""
    <h2>Sign in to Emakola</h2>
    <p>Click the link below to sign in. This link expires in 10 minutes.</p>
    <a href="#{url}">Sign in to Emakola</a>
    """)
    |> text_body("Sign in to Emakola: #{url}")
    |> Mailer.deliver()
  end

  def password_reset(user, token) do
    url = "#{EmakolaWeb.Endpoint.url()}/auth/reset-password?token=#{token}"

    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(Mailer.from_address("Emakola"))
    |> subject("Reset your Emakola password")
    |> html_body("""
    <h2>Password Reset</h2>
    <p>Click the link below to reset your password. This link expires in 1 hour.</p>
    <a href="#{url}">Reset Password</a>
    """)
    |> text_body("Reset your password: #{url}")
    |> Mailer.deliver()
  end
end
