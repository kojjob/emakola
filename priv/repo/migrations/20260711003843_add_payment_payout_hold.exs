defmodule Emakola.Repo.Migrations.AddPaymentPayoutHold do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add :payout_held, :boolean, null: false, default: false
      add :payout_hold_reason, :text
      add :payout_released_at, :utc_datetime_usec
    end

    create index(:payments, [:store_id, :status, :payout_held],
             name: :payments_payout_eligibility_index
           )
  end
end
