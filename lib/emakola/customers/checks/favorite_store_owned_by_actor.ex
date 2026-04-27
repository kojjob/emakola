defmodule Emakola.Customers.Checks.FavoriteStoreOwnedByActor do
  @moduledoc """
  Policy check for FavoriteStore creates: the inbound `customer_id`
  attribute on the changeset must match the actor's `:id`.

  Filter-based `expr/1` policies can't authorize creates (no row exists
  yet), so we read the changing attribute directly.
  """

  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts) do
    "actor's id matches the changeset's customer_id"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(%{id: actor_id}, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    case Ash.Changeset.get_attribute(changeset, :customer_id) do
      nil -> false
      ^actor_id -> true
      _ -> false
    end
  end

  def match?(_actor, _context, _opts), do: false
end
