defmodule Emakola.Repo.Migrations.AddPaymentSplitRecoveryTracking do
  use Ecto.Migration

  def change do
    alter table(:payment_splits) do
      add :recovered_amount, :bigint, null: false, default: 0
      add :reserved_recovery_amount, :bigint, null: false, default: 0
      add :recovery_amount, :bigint, null: false, default: 0
      add :recovery_applied_amount, :bigint, null: false, default: 0
      add :recovery_reversed_amount, :bigint, null: false, default: 0
      add :recovery_breakdown, :map, null: false, default: %{"items" => []}
    end

    create index(:payment_splits, [:recipient_store_id, :inserted_at],
             name: :payment_splits_recovery_queue_index,
             where: "reversed_amount > recovered_amount"
           )
  end
end
