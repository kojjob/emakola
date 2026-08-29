defmodule Emakola.Repo.Migrations.AddLowStockAlertedAtToVariants do
  use Ecto.Migration

  def change do
    alter table(:variants) do
      add :low_stock_alerted_at, :utc_datetime_usec
    end
  end
end
