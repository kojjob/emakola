defmodule Emakola.Repo.Migrations.CreateDigitalFiles do
  @moduledoc """
  Creates `digital_files` — downloadable assets attached to products. Used
  by both digital_download products (paid files delivered after order
  fulfillment) and preview files on any product type (publicly accessible
  samples like look books, demo videos, sample chapters).

  `byte_size` is `bigint`: digital downloads can reach multi-GB sizes
  (videos, software bundles, design packs), which overflows the 4-byte
  `integer` Postgres uses by default.

  FKs cascade on the product side so removing a product cleans up its
  files row; the underlying storage objects are cleaned up by a separate
  background job (added when we wire the storage adapter).
  """
  use Ecto.Migration

  def change do
    create table(:digital_files, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false

      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false

      add :file_name, :string, null: false
      add :storage_key, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :bigint, null: false
      add :position, :integer, null: false, default: 0
      add :is_preview, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:digital_files, [:store_id])
    create index(:digital_files, [:product_id])
    create unique_index(:digital_files, [:store_id, :storage_key])
  end
end
