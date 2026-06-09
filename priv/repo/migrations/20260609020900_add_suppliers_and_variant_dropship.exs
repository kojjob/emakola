defmodule Emakola.Repo.Migrations.AddSuppliersAndVariantDropship do
  @moduledoc """
  Phase 1 of the dropshipping feature.

  Creates the `suppliers` table (store-scoped third-party sources for
  dropshipped products, with contact + payment details) and links it to
  variants via a nullable `supplier_id`. A variant with a supplier is
  dropshipped; its availability is driven by the new `available` flag
  rather than numeric stock, and `cost_price` records the supplier cost
  in minor currency units (pesewas/kobo).
  """
  use Ecto.Migration

  def change do
    create table(:suppliers, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :store_id,
          references(:stores, type: :uuid, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :contact_phone, :string
      add :whatsapp_number, :string
      add :contact_email, :string
      add :payment_details, :map
      add :notes, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:suppliers, [:store_id, :name],
             name: "suppliers_unique_store_supplier_name_index"
           )

    alter table(:variants) do
      add :cost_price, :integer
      add :available, :boolean, null: false, default: true

      add :supplier_id,
          references(:suppliers, type: :uuid, on_delete: :nilify_all)
    end
  end
end
