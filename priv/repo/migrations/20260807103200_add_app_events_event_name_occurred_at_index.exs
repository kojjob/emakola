defmodule Emakola.Repo.Migrations.AddAppEventsEventNameOccurredAtIndex do
  @moduledoc """
  `app_events` had only a primary key. It gains a row on every storefront
  product view and search, and `OpportunitySignals` (`recent/1`,
  `alert_exists?/1`, `supplier_alerts/2`) filters by `event_name` +
  `occurred_at` window on every supplier-radar read — a sequential scan of
  the whole table. Concurrent — this table is write-heavy and growing.
  """
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(:app_events, [:event_name, :occurred_at],
        name: :app_events_event_name_occurred_at_index,
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(:app_events, [:event_name, :occurred_at],
        name: :app_events_event_name_occurred_at_index
      )
    )
  end
end
