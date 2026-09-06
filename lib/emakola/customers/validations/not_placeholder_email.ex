defmodule Emakola.Customers.Validations.NotPlaceholderEmail do
  @moduledoc """
  No public registration may claim a phone-placeholder email
  (`p<digits>@phone.customers.makola.io`) — that address belongs to a
  specific phone-first guest lookup, not a person.

  Without this, an attacker could register with a victim's phone number and
  an email set to that victim's own eventual placeholder address. The
  resulting row is credentialed, so it is not returned directly to a later
  unverified guest checkout with that phone — but
  `FindOrCreateCustomer.fallback_to_credential_less/4` looks the placeholder
  email up too, and would otherwise hand the attacker's row back as the
  "credential-less" fallback, binding the victim's order to it.
  """
  use Ash.Resource.Validation

  alias Emakola.Orders.CheckoutService

  @impl true
  def validate(changeset, _opts, _context) do
    email = changeset |> Ash.Changeset.get_attribute(:email) |> presence()

    if email && CheckoutService.placeholder_email?(email) do
      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :email,
         message: "Use your own email address"
       )}
    else
      :ok
    end
  end

  # Ash.CiString (email) does not implement String.ends_with?/2 — normalise
  # through to_string/1 first, the same trap ContactDetailPresent works around.
  defp presence(nil), do: nil
  defp presence(value), do: to_string(value)
end
