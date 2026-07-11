defmodule Emakola.Repo.Migrations.CreateResellerListingImages do
  use Ecto.Migration

  def change do
    create table(:reseller_listing_images, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :listing_id, references(:reseller_listings, type: :uuid, on_delete: :delete_all),
        null: false

      add :source_image_id, references(:images, type: :uuid, on_delete: :delete_all), null: false
      add :reseller_image_id, references(:images, type: :uuid, on_delete: :nilify_all)
      add :status, :text, null: false, default: "pending"
      add :storage_key, :text, null: false
      add :failure_reason, :text
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:reseller_listing_images, [:listing_id, :source_image_id])
    create unique_index(:reseller_listing_images, [:reseller_image_id])

    create constraint(:reseller_listing_images, :valid_status,
             check: "status IN ('pending', 'completed', 'failed')"
           )
  end
end
