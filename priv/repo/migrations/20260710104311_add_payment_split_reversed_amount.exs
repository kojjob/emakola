defmodule Emakola.Repo.Migrations.AddPaymentSplitReversedAmount do
  use Ecto.Migration

  def change do
    alter table(:payment_splits) do
      add :reversed_amount, :bigint, null: false, default: 0
    end
  end
end
