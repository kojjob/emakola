defmodule Emakola.Repo.Migrations.AddSupplierSlaClockToFulfillments do
  @moduledoc """
  Gives a paid order a clock, so a silent supplier stops being silent forever.

  🔴 DO NOT BACKFILL `respond_by`. Stamping historical `:pending` fulfilments
  would make the first cron tick after deploy escalate the entire accumulated
  backlog at once — a message storm, at the merchant's cost, about orders that
  are months dead. NULL means "no clock", the sweeper requires
  `not is_nil(respond_by)`, and so the clock starts only for orders confirmed
  after this ships. That is the intended behaviour, not an oversight.

  The clock is stamped at `Order.:confirm` rather than derived at read time.
  `notified_at` was unusable — it is written only when a message provider
  returned success, and production has placeholder WhatsApp credentials, so it
  is never written. `inserted_at` was unusable too: fulfilments are created at
  checkout, before payment, so a clock from there chases suppliers about carts
  nobody ever bought.
  """

  use Ecto.Migration

  def up do
    alter table(:fulfillments) do
      add(:respond_by, :utc_datetime_usec)
      add(:escalation_level, :bigint, null: false, default: 0)
      add(:escalated_at, :utc_datetime_usec)
    end

    create(index(:fulfillments, [:escalation_level, :respond_by]))
  end

  def down do
    drop(index(:fulfillments, [:escalation_level, :respond_by]))

    alter table(:fulfillments) do
      remove(:respond_by)
      remove(:escalation_level)
      remove(:escalated_at)
    end
  end
end
