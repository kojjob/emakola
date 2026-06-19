defmodule Emakola.Notifications.BillingMailer do
  @moduledoc "Billing-related transactional emails."
  import Swoosh.Email

  alias Emakola.Mailer

  def subscription_created(user, plan) do
    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(Mailer.from_address("Makola", "billing"))
    |> subject("Welcome to #{plan.name}!")
    |> html_body("""
    <h2>Subscription Confirmed</h2>
    <p>You're now on the <strong>#{plan.name}</strong> plan.</p>
    <p>Features included:</p>
    <ul>
    #{Enum.map_join(plan.features, "\n", &"<li>#{&1}</li>")}
    </ul>
    """)
    |> text_body("You're now on the #{plan.name} plan.")
    |> Mailer.deliver()
  end

  def payment_failed(user) do
    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(Mailer.from_address("Makola", "billing"))
    |> subject("Payment failed — action required")
    |> html_body("""
    <h2>Payment Failed</h2>
    <p>We were unable to process your payment. Please update your payment method to avoid service interruption.</p>
    <a href="#{EmakolaWeb.Endpoint.url()}/billing">Update Payment Method</a>
    """)
    |> text_body("Payment failed. Please update your payment method.")
    |> Mailer.deliver()
  end

  def subscription_canceled(user, plan) do
    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(Mailer.from_address("Makola", "billing"))
    |> subject("Your #{plan.name} subscription has been canceled")
    |> html_body("""
    <h2>Subscription Canceled</h2>
    <p>Your <strong>#{plan.name}</strong> plan has been canceled. You'll continue to have access until the end of your current billing period.</p>
    """)
    |> text_body("Your #{plan.name} subscription has been canceled.")
    |> Mailer.deliver()
  end
end
