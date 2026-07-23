defmodule Emakola.Customers.Actions.SetDefaultAddress do
  @moduledoc """
  Implementation for the Address set_as_default generic action.

  Clears is_default on all other addresses for the same customer,
  then sets the target address as default. Uses the internal
  `toggle_default` action which is the only way to modify is_default.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, context) do
    address_id = input.arguments.address_id

    address = Ash.get!(Emakola.Customers.Address, address_id, authorize?: false)

    with :ok <- authorize_actor(address, context.actor) do
      set_default(address, address_id)
    end
  end

  # nil actor = trusted system code (callers opt in via authorize?: false,
  # per the resource's policy convention). A customer actor may only touch
  # their own addresses; any other actor type is denied.
  defp authorize_actor(_address, nil), do: :ok

  defp authorize_actor(address, %Emakola.Customers.Customer{} = actor) do
    if address.customer_id == actor.id and address.store_id == actor.store_id do
      :ok
    else
      {:error, Ash.Error.Forbidden.exception([])}
    end
  end

  defp authorize_actor(_address, _actor), do: {:error, Ash.Error.Forbidden.exception([])}

  defp set_default(address, address_id) do
    # Clear all defaults for this customer
    Emakola.Customers.Address
    |> Ash.Query.filter(
      customer_id == ^address.customer_id and is_default == true and id != ^address_id
    )
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn addr ->
      addr
      |> Ash.Changeset.for_update(:toggle_default, %{is_default: false})
      |> Ash.update!(authorize?: false)
    end)

    # Set the target as default
    address
    |> Ash.Changeset.for_update(:toggle_default, %{is_default: true})
    |> Ash.update(authorize?: false)
  end
end
