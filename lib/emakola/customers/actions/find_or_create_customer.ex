defmodule Emakola.Customers.Actions.FindOrCreateCustomer do
  @moduledoc """
  Finds the customer a checkout belongs to, or creates one.

  Phone first: the storefront is phone-first, and `unique_store_phone` means a
  second row for a known number cannot be created anyway. Email second, for
  buyers who never gave a phone. The phone is normalised to E.164 before both
  the lookup and the create, so "020 111 2222" and "+233201112222" are one
  person.

  `verified?` (default false) guards against account takeover: an
  unverified caller — every storefront guest checkout, pay link, susu
  chunk, and the historical backfill — has not proven the phone or email it
  typed belongs to the person typing it. If that value matches an EXISTING
  row that holds credentials (a password hash, or a social identity), that
  row is not returned — an unverified match binds a stranger's order (name,
  address, items, notifications) to someone else's account otherwise. The
  match falls back to a credential-less row keyed by the phone placeholder
  email instead, creating it if absent. Only a caller who has actually
  verified the identity (there is none yet; signed-in checkout uses
  customer_id directly and never reaches this action) would pass true.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Emakola.Customers.CustomerIdentity
  alias Emakola.Orders.CheckoutService

  @impl true
  def run(input, _opts, _context) do
    email = input.arguments.email
    store_id = input.arguments.store_id
    name = input.arguments[:name]
    phone = normalize_phone(input.arguments[:phone])
    verified? = input.arguments[:verified?] || false
    resource = input.resource

    case find_existing(resource, email, phone, store_id) do
      nil ->
        create_or_find_on_conflict(resource, email, store_id, name, phone)

      customer ->
        if verified? or not credentialed?(customer) do
          {:ok, customer}
        else
          fallback_to_credential_less(resource, store_id, name, phone)
        end
    end
  end

  defp credentialed?(customer) do
    not is_nil(customer.hashed_password) or has_identity?(customer)
  end

  defp has_identity?(customer) do
    CustomerIdentity
    |> Ash.Query.filter(user_id == ^customer.id and store_id == ^customer.store_id)
    |> Ash.exists?(authorize?: false)
  end

  # No phone means there is nothing safe to key the fallback row on — this
  # is not reachable from any current caller (every one either has a phone
  # by the time it calls this action, or never matches a credentialed row
  # because it never had a phone to match on in the first place), but an
  # unverified caller must still never get the credentialed row back.
  defp fallback_to_credential_less(_resource, _store_id, _name, nil),
    do: {:error, :customer_creation_failed}

  defp fallback_to_credential_less(resource, store_id, name, phone) do
    placeholder_email = CheckoutService.phone_placeholder_email(phone)

    case by_email(resource, placeholder_email, store_id) do
      nil ->
        resource
        |> Ash.Changeset.for_create(:create, %{
          email: placeholder_email,
          store_id: store_id,
          name: name,
          phone: nil
        })
        |> Ash.create(authorize?: false)

      customer ->
        {:ok, customer}
    end
  end

  defp normalize_phone(nil), do: nil

  defp normalize_phone(phone) when is_binary(phone) do
    # PhoneAuth.normalize/1 always succeeds — a blank, digit-free, or
    # otherwise garbage phone ("abc", "+233", 30 digits of nonsense) still
    # comes back looking like a phone. valid?/1 is the actual gate: an
    # invalid phone is stored as no phone at all, not as whatever garbage
    # normalise produced.
    if Emakola.Accounts.PhoneAuth.valid?(phone) do
      Emakola.Accounts.PhoneAuth.normalize(phone)
    end
  end

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
