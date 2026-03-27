defmodule Emakola.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all)
      add :author_id, references(:merchants, type: :uuid, on_delete: :nilify_all)
      add :type, :string, null: false
      add :title, :string, null: false, size: 255
      add :slug, :string, null: false, size: 255
      add :body, :text
      add :excerpt, :string, size: 500
      add :featured_image_url, :string
      add :seo_title, :string, size: 255
      add :seo_description, :string, size: 1000
      add :status, :string, null: false, default: "draft"
      add :published_at, :utc_datetime_usec
      add :tags, {:array, :string}, default: []
      add :ai_generated, :boolean, default: false
      add :view_count, :integer, default: 0
      timestamps(type: :utc_datetime_usec)
    end

    create index(:posts, [:store_id])
    create index(:posts, [:author_id])
    create index(:posts, [:status])
    create index(:posts, [:type])
    create index(:posts, [:published_at])
    create unique_index(:posts, [:store_id, :slug, :type])
  end
end
