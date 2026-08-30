defmodule Emakola.Repo.Migrations.AddPaymentsPayoutIdIndexConcurrently do
  @moduledoc """
  `release_payout_balance` (`paystack_webhook_handler.ex`) scans payments by
  `payout_id` on every `transfer.failed`/`transfer.reversed` webhook — the
  column had no index. Partial (non-null) since most payments never have a
  payout_id. Concurrent — payments is a hot, growing table.
  """
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(:payments, [:payout_id],
        where: "payout_id IS NOT NULL",
        name: :payments_payout_id_index,
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(index(:payments, [:payout_id], name: :payments_payout_id_index))
  end
end
