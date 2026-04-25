defmodule Emakola.Repo.Migrations.CreateStorefrontPages do
  @moduledoc """
  Adds the storefront_pages table — backing store for the merchant page builder.

  A page is an ordered list of blocks (json) attached to a store at a slug.
  When a published page exists at slug "home", `StoreLive` renders the page
  via the page builder pipeline instead of falling through to the active
  theme's home renderer. Otherwise the theme home renders unchanged —
  the builder is opt-in.

  Schema notes:
  * (store_id, slug) is unique — one page per slug per store
  * blocks defaults to [] so a freshly created page is renderable as empty
  * meta defaults to %{} for SEO overrides
  * published is gated on render — drafts never reach the storefront
  """
  use Ecto.Migration

  def change do
    create table(:storefront_pages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false

      add :slug, :string, null: false, size: 80
      add :title, :string, null: false, size: 255
      add :published, :boolean, null: false, default: false
      add :blocks, {:array, :map}, null: false, default: []
      add :meta, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:storefront_pages, [:store_id, :slug],
             name: "storefront_pages_unique_store_slug_index"
           )

    create index(:storefront_pages, [:store_id])
  end
end
