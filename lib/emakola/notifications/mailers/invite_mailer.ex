defmodule Emakola.Notifications.InviteMailer do
  @moduledoc "Sends team invitation emails."
  import Swoosh.Email

  alias Emakola.Mailer

  @from {"Emakola", "noreply@emakola.com"}

  def invite(email, org_name) do
    register_url = "#{EmakolaWeb.Endpoint.url()}/auth/register"

    new()
    |> to(email)
    |> from(@from)
    |> subject("You've been invited to join #{org_name} on Emakola")
    |> html_body("""
    <h2>You're invited!</h2>
    <p>You've been invited to join <strong>#{org_name}</strong> on Emakola.</p>
    <p>Create your account to get started:</p>
    <a href="#{register_url}">Join #{org_name}</a>
    """)
    |> text_body(
      "You've been invited to join #{org_name} on Emakola. Sign up at: #{register_url}"
    )
    |> Mailer.deliver()
  end
end
