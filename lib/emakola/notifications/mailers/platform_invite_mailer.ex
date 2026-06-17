defmodule Emakola.Notifications.Mailers.PlatformInviteMailer do
  @moduledoc "Platform staff invitation email — carries the raw invite token link."
  import Swoosh.Email

  alias Emakola.Mailer

  @from {"Emakola", "noreply@emakola.com"}

  def invite(email, raw_token, inviter_name) do
    url = "#{EmakolaWeb.Endpoint.url()}/platform/invite/accept/#{raw_token}"
    safe_inviter = Plug.HTML.html_escape(inviter_name)

    new()
    |> to(email)
    |> from(@from)
    |> subject("You've been invited to the Emakola platform team")
    |> html_body("""
    <h2>Join the Emakola platform team</h2>
    <p>#{safe_inviter} has invited you to the Emakola platform team.</p>
    <p>Click the link below to create your account. This link expires in 7 days.</p>
    <a href="#{url}">Accept invitation</a>
    """)
    |> text_body(
      "#{inviter_name} has invited you to the Emakola platform team. " <>
        "Accept the invitation (expires in 7 days): #{url}"
    )
    |> Mailer.deliver()
  end
end
