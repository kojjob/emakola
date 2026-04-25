defmodule Emakola.Policies.Checks.ActorHasStoreAccess do
  @moduledoc """
  Policy check that verifies the actor (Merchant) has access to the resource's store.

  For tenant-scoped resources, this check ensures the merchant has a StoreMembership
  for the store_id on the resource. The actor must be a Merchant struct with
  preloaded `store_memberships` or we look up the membership.

  This check operates differently depending on the action type:
  - For create/update/destroy: checks the resource's store_id against the actor's stores
  - For read: checks the query's tenant against the actor's stores (enforces cross-tenant
    isolation when multitenancy :attribute is declared on the resource)
  """

  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_opts) do
    "actor has access to the resource's store via StoreMembership"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    store_id = get_store_id(changeset)
    actor_has_store?(actor, store_id)
  end

  def match?(actor, %{subject: %Ash.Query{} = query}, _opts) do
    # For reads with multitenancy, the tenant is set on the query.
    # Check that the actor has a store membership for the tenant store.
    # If no tenant is set, fall back to checking if the actor is a known struct
    # (to preserve backward-compatibility with non-tenant-scoped queries).
    case query.tenant do
      nil ->
        is_struct(actor)

      store_id ->
        actor_has_store?(actor, store_id)
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp get_store_id(%Ash.Changeset{} = changeset) do
    # For the Store resource itself, the resource's id IS the store_id
    if changeset.resource == Emakola.Accounts.Store do
      Map.get(changeset.data || %{}, :id)
    else
      # Try the changeset data first (for updates), then arguments/attributes (for creates)
      Ash.Changeset.get_attribute(changeset, :store_id) ||
        Map.get(changeset.data || %{}, :store_id)
    end
  end

  defp get_store_id(_), do: nil

  defp actor_has_store?(_actor, nil), do: false

  defp actor_has_store?(%{store_memberships: memberships}, store_id)
       when is_list(memberships) do
    Enum.any?(memberships, fn m -> m.store_id == store_id end)
  end

  defp actor_has_store?(%{id: merchant_id} = actor, store_id) do
    if is_merchant?(actor) do
      lookup_membership(merchant_id, store_id)
    else
      false
    end
  end

  defp actor_has_store?(_actor, _store_id), do: false

  defp is_merchant?(%Emakola.Accounts.Merchant{}), do: true
  defp is_merchant?(_), do: false

  defp lookup_membership(merchant_id, store_id) do
    case Emakola.Accounts.StoreMembership
         |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end
end
