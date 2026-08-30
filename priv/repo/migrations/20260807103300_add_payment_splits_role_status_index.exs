defmodule Emakola.Repo.Migrations.AddPaymentSplitsRoleStatusIndex do
  @moduledoc """
  FinanceStats.platform_fee_splits/0 filters `role == :platform and status !=
  :pending` on every /platform/finance load and every payout
  approval/retry, with no supporting index. Concurrent — payment_splits
  grows with every settled transaction, same as payments.
  """
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(:payment_splits, [:role, :status],
        name: :payment_splits_role_status_index,
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(:payment_splits, [:role, :status], name: :payment_splits_role_status_index)
    )
  end
end
