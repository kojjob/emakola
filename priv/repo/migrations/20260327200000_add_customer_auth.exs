defmodule Emakola.Repo.Migrations.AddCustomerAuth do
  use Ecto.Migration

  def change do
    alter table(:customers) do
      add :hashed_password, :string
    end

    create table(:customer_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :jti, :string, null: false
      add :subject, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :purpose, :string, null: false
      add :extra_data, :map, default: %{}
      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(:customer_tokens, [:jti])
  end
end
