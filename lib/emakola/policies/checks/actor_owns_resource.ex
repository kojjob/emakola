defmodule Emakola.Policies.Checks.ActorOwnsResource do
  @moduledoc """
  Policy check that verifies the actor's ID matches the resource's ID.

  Used for User and Merchant resources to ensure users can only modify their own records.
  For read actions, this is typically combined with a more permissive policy.
  """

  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts) do
    "actor's ID matches the resource ID"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: %{data: %{id: id}}}, _opts) when not is_nil(id) do
    actor.id == id
  end

  def match?(actor, %{query: _query}, _opts) do
    # For reads, we allow — filtering should handle scoping
    is_struct(actor)
  end

  def match?(_actor, _context, _opts), do: false
end
