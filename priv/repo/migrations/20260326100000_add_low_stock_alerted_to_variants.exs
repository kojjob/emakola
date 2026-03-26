defmodule Emakola.Repo.Migrations.AddLowStockAlertedToVariants do
  use Ecto.Migration

  def change do
    alter table(:variants) do
      add :low_stock_alerted, :boolean, default: false, null: false
    end
  end
end
