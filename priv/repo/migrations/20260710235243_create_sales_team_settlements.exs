defmodule Emakola.Repo.Migrations.CreateSalesTeamSettlements do
  use Ecto.Migration

  def change do
    create table(:earn_sales_team_settlements, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :order_id, references(:orders, type: :uuid, on_delete: :restrict), null: false
      add :payment_id, references(:payments, type: :uuid, on_delete: :restrict), null: false
      add :team_id, references(:earn_sales_teams, type: :uuid, on_delete: :restrict), null: false

      add :team_member_id,
          references(:earn_sales_team_members, type: :uuid, on_delete: :restrict), null: false

      add :merchant_id, references(:merchants, type: :uuid, on_delete: :restrict), null: false
      add :role, :string, null: false
      add :split_bps, :integer, null: false
      add :settlement_base, :bigint, null: false
      add :amount, :bigint, null: false
      add :status, :string, null: false, default: "settled"
      add :reversed_amount, :bigint, null: false, default: 0
      add :settled_at, :utc_datetime_usec, null: false
      add :reversed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_sales_team_settlements, [:payment_id, :team_member_id])
    create index(:earn_sales_team_settlements, [:merchant_id, :status])
    create index(:earn_sales_team_settlements, [:store_id, :order_id])

    create constraint(:earn_sales_team_settlements, :sales_team_settlement_role_valid,
             check: "role IN ('owner', 'content', 'seller', 'support')"
           )

    create constraint(:earn_sales_team_settlements, :sales_team_settlement_split_valid,
             check: "split_bps > 0 AND split_bps <= 10000"
           )

    create constraint(:earn_sales_team_settlements, :sales_team_settlement_amount_valid,
             check: "settlement_base >= 0 AND amount >= 0 AND amount <= settlement_base"
           )

    create constraint(:earn_sales_team_settlements, :sales_team_settlement_status_valid,
             check: "status IN ('settled', 'partially_reversed', 'reversed')"
           )
  end
end
