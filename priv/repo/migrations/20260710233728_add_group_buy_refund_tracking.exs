defmodule Emakola.Repo.Migrations.AddGroupBuyRefundTracking do
  use Ecto.Migration

  def up do
    alter table(:earn_group_buy_commitments) do
      add :refund_attempted_at, :utc_datetime_usec
      add :refund_reference, :text
      add :refund_error, :text
    end

    drop constraint(:earn_group_buy_commitments, :group_buy_commitment_status_valid)

    create constraint(:earn_group_buy_commitments, :group_buy_commitment_status_valid,
             check:
               "status IN ('pending', 'paid', 'cancelled', 'refunding', 'refunded', 'refund_failed')"
           )
  end

  def down do
    drop constraint(:earn_group_buy_commitments, :group_buy_commitment_status_valid)

    create constraint(:earn_group_buy_commitments, :group_buy_commitment_status_valid,
             check: "status IN ('pending', 'paid', 'cancelled', 'refunded')"
           )

    alter table(:earn_group_buy_commitments) do
      remove :refund_attempted_at
      remove :refund_reference
      remove :refund_error
    end
  end
end
