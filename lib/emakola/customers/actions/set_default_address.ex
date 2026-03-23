defmodule Emakola.Customers.Actions.SetDefaultAddress do
  @moduledoc """
  Implementation for the Address set_as_default generic action.

  Clears is_default on all other addresses for the same customer,
  then sets the target address as default.

  Extracted to a separate module because it needs to query and update
  sibling records, which cannot be done from a regular update action.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, _context) do
    address_id = input.arguments.address_id

    address = Ash.get!(Emakola.Customers.Address, address_id)

    # Clear all defaults for this customer
    Emakola.Customers.Address
    |> Ash.Query.filter(
      customer_id == ^address.customer_id and is_default == true and id != ^address_id
    )
    |> Ash.read!()
    |> Enum.each(fn addr ->
      addr
      |> Ash.Changeset.for_update(:update, %{is_default: false})
      |> Ash.update!()
    end)

    # Set the target as default
    address
    |> Ash.Changeset.for_update(:update, %{is_default: true})
    |> Ash.update()
  end
end
