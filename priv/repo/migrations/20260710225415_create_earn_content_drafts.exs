defmodule Emakola.Repo.Migrations.CreateEarnContentDrafts do
  use Ecto.Migration

  def change do
    create table(:earn_content_drafts, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false

      add :listing_id, references(:reseller_listings, type: :uuid, on_delete: :delete_all),
        null: false

      add :kind, :text, null: false
      add :locale, :text, null: false, default: "en-GH"
      add :status, :text, null: false, default: "draft"
      add :source_facts, :map, null: false, default: %{}
      add :source_facts_hash, :text, null: false
      add :content, :map, null: false, default: %{}
      add :generator, :text, null: false, default: "deterministic"
      add :approved_at, :utc_datetime_usec
      add :approved_by_id, references(:merchants, type: :uuid, on_delete: :nilify_all)
      timestamps(type: :utc_datetime_usec)
    end

    create index(:earn_content_drafts, [:store_id, :status])
    create index(:earn_content_drafts, [:listing_id, :inserted_at])

    create constraint(:earn_content_drafts, :earn_content_drafts_kind_valid,
             check: "kind IN ('sales_kit', 'product_page', 'short_video', 'faq')"
           )

    create constraint(:earn_content_drafts, :earn_content_drafts_status_valid,
             check: "status IN ('draft', 'approved', 'rejected', 'stale')"
           )
  end
end
