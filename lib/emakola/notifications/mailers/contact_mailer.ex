defmodule Emakola.Notifications.ContactMailer do
  @moduledoc "Sends contact-form submissions to the support inbox."
  import Swoosh.Email

  alias Emakola.Mailer

  def deliver_contact_message(%{name: name, email: email, subject: subject, message: message}) do
    to_address = Application.get_env(:emakola, :contact_email, "support@emakola.com")

    new()
    |> to(to_address)
    |> from(Mailer.from_address("Makola Contact Form"))
    |> reply_to(email)
    |> subject("[Contact] #{subject}")
    |> text_body("""
    New contact form submission

    Name: #{name}
    Email: #{email}
    Subject: #{subject}

    #{message}
    """)
    |> html_body("""
    <h2>New contact form submission</h2>
    <p><strong>Name:</strong> #{Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()}</p>
    <p><strong>Email:</strong> #{Phoenix.HTML.html_escape(email) |> Phoenix.HTML.safe_to_string()}</p>
    <p><strong>Subject:</strong> #{Phoenix.HTML.html_escape(subject) |> Phoenix.HTML.safe_to_string()}</p>
    <p>#{Phoenix.HTML.html_escape(message) |> Phoenix.HTML.safe_to_string()}</p>
    """)
    |> Mailer.deliver()
  end
end
