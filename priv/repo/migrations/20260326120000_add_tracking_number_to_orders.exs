defmodule Emakola.Repo.Migrations.AddTrackingNumberToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :tracking_number, :string, size: 100
    end
  end
end
