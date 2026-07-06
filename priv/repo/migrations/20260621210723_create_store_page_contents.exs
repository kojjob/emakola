defmodule Emakola.Repo.Migrations.CreateStorePageContents do
  @moduledoc """
  Per-store editable prose for the storefront informational pages
  (About, Contact, FAQ, Policies). One row per store.
  """

  use Ecto.Migration

  def up do
    create table(:store_page_contents, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :store_id,
          references(:stores,
            column: :id,
            name: "store_page_contents_store_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :about_headline, :text
      add :about_intro, :text
      add :about_story, :text
      add :about_steps, {:array, :map}, null: false, default: []
      add :about_values, {:array, :map}, null: false, default: []
      add :about_cta_heading, :text
      add :about_cta_text, :text
      add :faq_items, {:array, :map}, null: false, default: []
      add :shipping_returns, :text
      add :privacy_policy, :text
      add :terms_of_service, :text
      add :contact_note, :text
      add :contact_hours, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:store_page_contents, [:store_id],
             name: "store_page_contents_unique_store_page_content_index"
           )
  end

  def down do
    drop constraint(:store_page_contents, "store_page_contents_store_id_fkey")

    drop_if_exists unique_index(:store_page_contents, [:store_id],
                     name: "store_page_contents_unique_store_page_content_index"
                   )

    drop table(:store_page_contents)
  end
end
