defmodule Emakola.Repo.Migrations.AddWhatsappCatalogIdToStores do
  @moduledoc """
  Adds whatsapp_catalog_id to stores so merchants can link their WhatsApp
  Business Catalog. When set, product publish/update events enqueue a
  background sync to keep the WhatsApp Catalog mirrored with the storefront.

  Nullable — stores that haven't connected a catalog get NULL and the
  sync worker skips them silently.

  Phase 2 of the social media integration plan.
  """
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :whatsapp_catalog_id, :string
    end
  end
end
