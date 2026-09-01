defmodule Emakola.Repo.Migrations.AddOrderDeliveryTimestamps do
  @moduledoc """
  When an order was marked shipped and delivered. Both nullable: orders
  from before this migration keep nil, and delivery metrics treat them
  as delivered but not timed.

  Hand-trimmed from `mix ash.codegen` output — the resource snapshots
  lag the applied migrations, so codegen also emitted a dozen unrelated
  tables that already exist.
  """

  use Ecto.Migration

  def up do
    alter table(:orders) do
      add :shipped_at, :utc_datetime_usec
      add :delivered_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:orders) do
      remove :delivered_at
      remove :shipped_at
    end
  end
end
