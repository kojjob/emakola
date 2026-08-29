defmodule Emakola.Repo.Migrations.AddDevicePairings do
  @moduledoc """
  Scan-to-sign-in requests (QR Phase 4).

  Hand-written rather than generated: `mix ash.codegen` in this tree emitted a
  migration recreating 89 tables, because the committed resource snapshots have
  drifted from what the current Ash version produces. That is worth fixing on
  its own, but not inside a feature branch — and certainly not by shipping a
  migration that recreates the whole schema.
  """

  use Ecto.Migration

  def up do
    create table(:device_pairings, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(
        :merchant_id,
        references(:merchants, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:token_digest, :text, null: false)
      add(:expires_at, :utc_datetime_usec, null: false)
      add(:status, :text, null: false, default: "pending")
      add(:scanned_by, :text)
      add(:scanned_at, :utc_datetime_usec)
      add(:confirmed_at, :utc_datetime_usec)
      add(:consumed_at, :utc_datetime_usec)

      add(:inserted_at, :utc_datetime_usec, null: false, default: fragment("now()"))
      add(:updated_at, :utc_datetime_usec, null: false, default: fragment("now()"))
    end

    # The digest is how a scanning phone is found — it presents the token and
    # nothing else — so this index is on the read path of every scan, not just a
    # uniqueness guard.
    create(unique_index(:device_pairings, [:token_digest]))

    # The desktop polls for its own pending pairings while the code is on screen.
    create(index(:device_pairings, [:merchant_id, :status]))
  end

  def down do
    drop(table(:device_pairings))
  end
end
