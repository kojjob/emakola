defmodule Emakola.Repo.Migrations.AddIsPublicToCoupons do
  use Ecto.Migration

  def change do
    alter table(:coupons) do
      add :is_public, :boolean, default: false, null: false
    end
  end
end
