defmodule Emakola.Repo.Migrations.AddDirectoryFieldsToStores do
  @moduledoc """
  Adds the columns the public `/stores` directory needs to surface
  meaningful information (cover, tagline) and rank stores (featured
  flag + manual rank, verified badge, view counter for popularity).
  """
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :featured, :boolean, default: false, null: false
      add :featured_rank, :integer
      add :verified, :boolean, default: false, null: false
      add :cover_image_url, :string
      add :view_count, :integer, default: 0, null: false
      add :tagline, :string, size: 140
    end

    create index(:stores, [:featured])
    create index(:stores, [:featured_rank])
    create index(:stores, [:active, :featured])
  end
end
