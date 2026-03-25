defmodule Emakola.Repo.Migrations.EnhanceCustomersDomain do
  @moduledoc """
  Enhances the Customers domain with tags, last_order_at,
  addresses table, and customer_notes table.
  """

  use Ecto.Migration

  def up do
    # 1. Alter existing customers table
    alter table(:customers) do
      add :tags, {:array, :text}, default: []
      add :last_order_at, :utc_datetime_usec
    end

    # 2. Create addresses table
    create table(:addresses, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :customer_id,
          references(:customers,
            column: :id,
            name: "addresses_customer_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :store_id,
          references(:stores,
            column: :id,
            name: "addresses_store_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :label, :text
      add :first_name, :text
      add :last_name, :text
      add :line_1, :text, null: false
      add :line_2, :text
      add :city, :text, null: false
      add :region, :text
      add :country, :text, null: false, default: "GH"
      add :postal_code, :text
      add :phone, :text
      add :is_default, :boolean, null: false, default: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:addresses, [:customer_id, :store_id], name: "addresses_customer_store_index")

    # 3. Create customer_notes table
    create table(:customer_notes, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :customer_id,
          references(:customers,
            column: :id,
            name: "customer_notes_customer_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :store_id,
          references(:stores,
            column: :id,
            name: "customer_notes_store_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :author_id,
          references(:merchants,
            column: :id,
            name: "customer_notes_author_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :content, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:customer_notes, [:customer_id, :store_id],
             name: "customer_notes_customer_store_index"
           )
  end

  def down do
    drop_if_exists index(:customer_notes, [:customer_id, :store_id],
                     name: "customer_notes_customer_store_index"
                   )

    drop constraint(:customer_notes, "customer_notes_customer_id_fkey")
    drop constraint(:customer_notes, "customer_notes_store_id_fkey")
    drop constraint(:customer_notes, "customer_notes_author_id_fkey")
    drop table(:customer_notes)

    drop_if_exists index(:addresses, [:customer_id, :store_id],
                     name: "addresses_customer_store_index"
                   )

    drop constraint(:addresses, "addresses_customer_id_fkey")
    drop constraint(:addresses, "addresses_store_id_fkey")
    drop table(:addresses)

    alter table(:customers) do
      remove :tags
      remove :last_order_at
    end
  end
end
