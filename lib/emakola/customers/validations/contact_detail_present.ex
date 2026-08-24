defmodule Emakola.Customers.Validations.ContactDetailPresent do
  @moduledoc """
  A customer must be reachable by something — a phone number or an email.

  `email` became optional so buyers without one can register by phone, which
  is how most people in this market actually sign up. That freedom stops
  short of creating a customer nobody can contact: a shop that cannot tell
  someone their order shipped has not really taken an order.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    phone = Ash.Changeset.get_attribute(changeset, :phone)
    email = Ash.Changeset.get_attribute(changeset, :email)

    if present?(phone) or present?(email) do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :phone,
         message: "a customer needs a phone number or an email address"
       )}
    end
  end

  # Ash.CiString (email) does not implement String.trim/1 — normalise through
  # to_string/1 first, the same trap that crashes String.first on CiString.
  defp present?(nil), do: false
  defp present?(value), do: value |> to_string() |> String.trim() != ""
end
