defmodule Emakola.Repo.Migrations.AddAbandonedCheckouts do
  @moduledoc """
  Checkouts where a buyer typed a phone and never placed the order.
  Hand-written. One row per cart session per store; the row is updated in
  place while the buyer is still on the page.
  """

  use Ecto.Migration

  def up do
    create table(:abandoned_checkouts, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(
        :store_id,
        references(:stores, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:cart_session_id, :text, null: false)
      add(:phone, :text, null: false)
      add(:name, :text)
      add(:items, {:array, :map}, null: false, default: [])
      add(:cart_total, :bigint, null: false, default: 0)
      add(:last_seen_at, :utc_datetime_usec, null: false)
      add(:recovered_order_id, :uuid)
      add(:recovered_at, :utc_datetime_usec)
      add(:inserted_at, :utc_datetime_usec, null: false, default: fragment("now()"))
      add(:updated_at, :utc_datetime_usec, null: false, default: fragment("now()"))
    end

    create(unique_index(:abandoned_checkouts, [:store_id, :cart_session_id]))
    create(index(:abandoned_checkouts, [:store_id, :last_seen_at]))
    create(index(:abandoned_checkouts, [:store_id, :phone]))
  end

  def down do
    drop(table(:abandoned_checkouts))
  end
end
