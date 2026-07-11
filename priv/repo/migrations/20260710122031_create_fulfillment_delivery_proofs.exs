defmodule Emakola.Repo.Migrations.CreateFulfillmentDeliveryProofs do
  use Ecto.Migration

  def change do
    create table(:fulfillment_delivery_proofs, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :fulfillment_id, references(:fulfillments, type: :uuid, on_delete: :delete_all),
        null: false

      add :code_hash, :text, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :attempts, :integer, null: false, default: 0
      add :sent_to, :text, null: false
      add :verified_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fulfillment_delivery_proofs, [:fulfillment_id])

    create constraint(:fulfillment_delivery_proofs, :non_negative_attempts,
             check: "attempts >= 0"
           )
  end
end
