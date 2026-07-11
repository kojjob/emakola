defmodule Emakola.Repo.Migrations.AddFranchiseActivationTracking do
  use Ecto.Migration

  def change do
    alter table(:earn_franchise_enrollments) do
      add :approved_at, :utc_datetime_usec
      add :activated_listing_ids, {:array, :uuid}, null: false, default: []
    end
  end
end
