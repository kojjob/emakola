defmodule Emakola.Repo.Migrations.CreateRecipeMeta do
  use Ecto.Migration

  def change do
    create table(:recipe_meta, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), null: false
      add :prep_time, :integer
      add :cook_time, :integer
      add :servings, :integer
      add :difficulty, :string
      add :ingredients, {:array, :map}, default: []
      add :instructions, {:array, :string}, default: []
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:recipe_meta, [:post_id])
  end
end
