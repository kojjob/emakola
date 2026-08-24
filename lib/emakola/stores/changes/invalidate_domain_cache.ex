defmodule Emakola.Stores.Changes.InvalidateDomainCache do
  @moduledoc """
  Drops the cached host lookup and the store's cached primary host after any
  `StoreDomain` write.

  Attached globally on the resource rather than per action, so no future
  transition can forget it.

  `StoreCache.invalidate_store/2` cannot do this job: it matches keys shaped
  `resource:store_id:qualifier`, and neither `domain_host:<host>` nor
  `store_primary_host:<slug>` has that shape. The invalidation has to be
  explicit and by key.

  Runs in `after_transaction`, so it fires at a real commit rather than before
  one. It only ever *clears* keys — never writes one — because inside a
  surrounding transaction the hook fires early, and caching a value read from
  an uncommitted write would outlive a rollback. Clearing early is harmless.

  When a write is wrapped in an outer transaction (`Stores.Domains.claim/3`),
  that caller invalidates again after the real commit.
  """

  use Ash.Resource.Change

  alias Emakola.Stores.DomainResolver

  @impl true
  def change(changeset, _opts, _context) do
    # Captured before the action: if :host changed, the OLD key must go too.
    previous_host = changeset.data && Map.get(changeset.data, :host)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      case result do
        {:ok, record} ->
          DomainResolver.invalidate(previous_host)
          DomainResolver.invalidate(record.host)
          DomainResolver.invalidate_slug(slug_for(record.store_id))
          result

        other ->
          other
      end
    end)
  end

  defp slug_for(nil), do: nil

  defp slug_for(store_id) do
    case Ash.get(Emakola.Stores.Store, store_id, authorize?: false, not_found_error?: false) do
      {:ok, %{slug: slug}} -> slug
      _ -> nil
    end
  end
end
