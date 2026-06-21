defmodule Emakola.Repo.Migrations.AddPhoneLoginIdentities do
  use Ecto.Migration

  def up do
    create unique_index(:merchants, [:phone], name: "merchants_unique_phone_index")

    create unique_index(:customers, [:store_id, :phone],
             name: "customers_unique_store_phone_index"
           )
  end

  def down do
    drop_if_exists unique_index(:merchants, [:phone], name: "merchants_unique_phone_index")

    drop_if_exists unique_index(:customers, [:store_id, :phone],
                     name: "customers_unique_store_phone_index"
                   )
  end
end
