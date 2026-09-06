defmodule Emakola.Repo.Migrations.AddAbandonedCheckoutsLastSeenIndex do
  @moduledoc """
  The nightly prune worker scans `last_seen_at` across every store with no
  `store_id` predicate. The existing `(store_id, last_seen_at)` composite
  index cannot serve that query efficiently — a plain index on
  `last_seen_at` alone can.
  """

  use Ecto.Migration

  def up do
    create(index(:abandoned_checkouts, [:last_seen_at]))
  end

  def down do
    drop(index(:abandoned_checkouts, [:last_seen_at]))
  end
end
