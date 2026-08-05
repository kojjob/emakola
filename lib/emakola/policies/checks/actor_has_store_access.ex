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
    # Reads without an explicit tenant are denied: callers must either use
    # authorize?: false (system/pipeline code) or Ash.Query.set_tenant/2.
    case query.tenant do
      nil ->
        false

      store_id ->
        actor_has_store?(actor, store_id)
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp get_store_id(%Ash.Changeset{} = changeset) do
    if changeset.resource == Emakola.Stores.Store do
      Map.get(changeset.data || %{}, :id)
    else
      # For attribute-strategy multitenant resources, tenant == store_id by
      # construction, so it is safe (and necessary for atomic destroys where
      # changeset.data is unavailable) to prefer the caller-supplied tenant.
      #
      # For NON-multitenant resources (e.g. StoreMembership), we must ignore
      # any caller-supplied tenant and read store_id from the row itself.
      # Trusting the tenant here would let an attacker supply their own store's
      # tenant and pass the membership check against a row in a different store
      # (fail-open).
      if Ash.Resource.Info.multitenancy_strategy(changeset.resource) == :attribute do
        changeset.tenant || safe_get_attribute(changeset, :store_id)
      else
        safe_get_attribute(changeset, :store_id)
      end
    end
  end

  # Ash.Changeset.get_attribute/2 calls get_data/2 for the original value,
  # which raises ArgumentError when changeset.data is OriginalDataNotAvailable
  # (atomic bulk operations). Match on that sentinel instead of rescuing so
  # the guard is explicit and zero-cost in the normal path.
  defp safe_get_attribute(
         %Ash.Changeset{data: %Ash.Changeset.OriginalDataNotAvailable{}} = cs,
         attr
       ),
       do: Map.get(cs.attributes, attr)

  defp safe_get_attribute(cs, attr), do: Ash.Changeset.get_attribute(cs, attr)

  defp actor_has_store?(_actor, nil), do: false

  defp actor_has_store?(%{store_memberships: memberships}, store_id)
       when is_list(memberships) do
    Enum.any?(memberships, fn m -> m.store_id == store_id end)
  end

  defp actor_has_store?(%{id: merchant_id} = actor, store_id) do
    if merchant?(actor) do
      lookup_membership(merchant_id, store_id)
    else
      false
    end
  end

  defp actor_has_store?(_actor, _store_id), do: false

  defp merchant?(%Emakola.Accounts.Merchant{}), do: true
  defp merchant?(_), do: false

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
