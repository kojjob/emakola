defmodule Emakola.Accounts.Validations.EnsureOwnerRemains do
  @moduledoc """
  Prevents demoting or deactivating the last active platform owner.

  An "active owner" is a user with `is_owner: true` and `deactivated_at: nil`.
  The change is rejected when it would strip ownership or deactivate the
  user and no other active owner exists.

  ## Known limitation — TOCTOU under READ COMMITTED

  Two concurrent owner-demotion requests can both pass this check: each
  reads the count of active owners before either write is committed, so
  both see "another owner exists" and proceed. The window is narrow
  (milliseconds between the `Ash.exists?` read and the UPDATE commit), but
  theoretically possible under PostgreSQL's default READ COMMITTED isolation.

  Recovery: `mix emakola.bootstrap_platform_owner` to re-promote a user.

  Tracked for a future hardening pass: replace the `Ash.exists?` probe with
  a `SELECT ... FOR UPDATE` advisory lock or a serialisable transaction so
  that only one demotion can win the race.
  """

  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    if removes_active_owner?(changeset) and not other_active_owner_exists?(changeset.data.id) do
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         message: "cannot demote or deactivate the last active platform owner"
       )}
    else
      :ok
    end
  end

  defp removes_active_owner?(changeset) do
    currently_active_owner? =
      changeset.data.is_owner && is_nil(changeset.data.deactivated_at)

    demoted? = Ash.Changeset.get_attribute(changeset, :is_owner) == false
    deactivated? = not is_nil(Ash.Changeset.get_attribute(changeset, :deactivated_at))

    currently_active_owner? and (demoted? or deactivated?)
  end

  defp other_active_owner_exists?(user_id) do
    Emakola.Accounts.User
    |> Ash.Query.filter(is_owner == true and is_nil(deactivated_at) and id != ^user_id)
    |> Ash.exists?(authorize?: false)
  end
end
