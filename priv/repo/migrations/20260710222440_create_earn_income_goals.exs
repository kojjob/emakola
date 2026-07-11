defmodule Emakola.Repo.Migrations.CreateEarnIncomeGoals do
  use Ecto.Migration

  def change do
    create table(:earn_income_goals, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :target_amount, :bigint, null: false
      add :timeframe_days, :integer, null: false
      add :daily_minutes, :integer, null: false
      add :channels, {:array, :text}, null: false, default: []
      add :status, :text, null: false, default: "active"
      add :starts_on, :date, null: false
      add :ends_on, :date, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:earn_income_goals, [:store_id, :status])

    create unique_index(:earn_income_goals, [:store_id],
             where: "status = 'active'",
             name: :earn_income_goals_one_active_per_store
           )

    create constraint(:earn_income_goals, :earn_income_goals_target_positive,
             check: "target_amount > 0"
           )

    create constraint(:earn_income_goals, :earn_income_goals_timeframe_valid,
             check: "timeframe_days BETWEEN 7 AND 90"
           )

    create constraint(:earn_income_goals, :earn_income_goals_daily_minutes_valid,
             check: "daily_minutes BETWEEN 10 AND 480"
           )

    create constraint(:earn_income_goals, :earn_income_goals_status_valid,
             check: "status IN ('active', 'completed', 'paused', 'cancelled')"
           )

    create constraint(:earn_income_goals, :earn_income_goals_dates_valid,
             check: "ends_on >= starts_on"
           )
  end
end
