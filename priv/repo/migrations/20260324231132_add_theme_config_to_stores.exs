defmodule Emakola.Repo.Migrations.AddThemeConfigToStores do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :theme_config, :map, default: %{}, null: false
    end
  end
end
