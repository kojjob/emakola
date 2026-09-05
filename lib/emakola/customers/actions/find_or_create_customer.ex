defmodule Emakola.Customers.Actions.FindOrCreateCustomer do
  @moduledoc """
  Finds the customer a checkout belongs to, or creates one.

  Phone first: the storefront is phone-first, and `unique_store_phone` means a
  second row for a known number cannot be created anyway. Email second, for
  buyers who never gave a phone. The phone is normalised to E.164 before both
  the lookup and the create, so "020 111 2222" and "+233201112222" are one
  person.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, _context) do
    email = input.arguments.email
    store_id = input.arguments.store_id
    name = input.arguments[:name]
    phone = normalize_phone(input.arguments[:phone])
    resource = input.resource

    case find_existing(resource, email, phone, store_id) do
      nil ->
        create_or_find_on_conflict(resource, email, store_id, name, phone)

      customer ->
        {:ok, customer}
    end
  end

  defp normalize_phone(nil), do: nil
  defp normalize_phone(""), do: nil

  defp normalize_phone(phone) when is_binary(phone),
    do: Emakola.Accounts.PhoneAuth.normalize(phone)

  defp find_existing(resource, email, phone, store_id) do
    by_phone(resource, phone, store_id) || by_email(resource, email, store_id)
  end

  defp by_phone(_resource, nil, _store_id), do: nil

  defp by_phone(resource, phone, store_id) do
    resource
    |> Ash.Query.filter(phone == ^phone and store_id == ^store_id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp by_email(resource, email, store_id) do
    resource
    |> Ash.Query.filter(email == ^email and store_id == ^store_id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp create_or_find_on_conflict(resource, email, store_id, name, phone) do
    case resource
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
          case find_existing(resource, email, phone, store_id) do
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
