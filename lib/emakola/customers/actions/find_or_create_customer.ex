defmodule Emakola.Customers.Actions.FindOrCreateCustomer do
  @moduledoc """
  Implementation for the Customer find_or_create generic action.

  Looks up a customer by email + store_id. Returns the existing customer
  if found, otherwise creates a new one with the provided attributes.

  Extracted to a separate module because Ash.Query.filter is a macro and
  cannot be used inside anonymous functions in Ash DSL action blocks.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, _context) do
    email = input.arguments.email
    store_id = input.arguments.store_id
    name = input.arguments[:name]
    phone = input.arguments[:phone]

    existing =
      Emakola.Customers.Customer
      |> Ash.Query.filter(email == ^email and store_id == ^store_id)
      |> Ash.read!()
      |> List.first()

    case existing do
      nil ->
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: email,
          store_id: store_id,
          name: name,
          phone: phone
        })
        |> Ash.create()

      customer ->
        {:ok, customer}
    end
  end
end
