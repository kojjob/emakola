defmodule Emakola.Repo.Migrations.CreateMediaAttachments do
  use Ecto.Migration

  def change do
    create table(:media_attachments, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all)
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :url, :string, null: false
      add :filename, :string
      add :alt_text, :string
      add :caption, :string
      add :position, :integer, default: 0
      add :ai_alt_text, :string
      add :file_size, :integer
      add :content_type, :string
      timestamps(type: :utc_datetime_usec)
    end

    create index(:media_attachments, [:post_id])
    create index(:media_attachments, [:store_id])
    create index(:media_attachments, [:type])
  end
end
