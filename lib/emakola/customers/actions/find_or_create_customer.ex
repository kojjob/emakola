defmodule Emakola.Customers.Actions.FindOrCreateCustomer do
  @moduledoc """
  Implementation for the Customer find_or_create generic action.

  Looks up a customer by email + store_id. Returns the existing customer
  if found, otherwise creates a new one with the provided attributes.

  Handles concurrent race conditions: if two checkouts for the same
  new email arrive simultaneously, the loser's create hits the
  unique_store_email constraint. We rescue and retry the lookup.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, _context) do
    email = input.arguments.email
    store_id = input.arguments.store_id
    name = input.arguments[:name]
    phone = input.arguments[:phone]

    case find_existing(email, store_id) do
      nil ->
        create_or_find_on_conflict(email, store_id, name, phone)

      customer ->
        {:ok, customer}
    end
  end

  defp find_existing(email, store_id) do
    Emakola.Customers.Customer
    |> Ash.Query.filter(email == ^email and store_id == ^store_id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp create_or_find_on_conflict(email, store_id, name, phone) do
    case Emakola.Customers.Customer
         |> Ash.Changeset.for_create(:create, %{
           email: email,
           store_id: store_id,
           name: name,
           phone: phone
         })
         |> Ash.create(authorize?: false) do
      {:ok, customer} ->
        {:ok, customer}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if uniqueness_error?(errors) do
          # Another process created this customer concurrently — find it
          case find_existing(email, store_id) do
            nil -> {:error, :customer_creation_failed}
            customer -> {:ok, customer}
          end
        else
          {:error, %Ash.Error.Invalid{errors: errors}}
        end
    end
  end

  defp uniqueness_error?(errors) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidChanges{message: msg} ->
        String.contains?(to_string(msg), "unique")

      %{message: msg} when is_binary(msg) ->
        String.contains?(msg, "unique") or String.contains?(msg, "already")

      _ ->
        false
    end)
  end
end
