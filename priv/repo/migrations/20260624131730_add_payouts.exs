defmodule Emakola.Repo.Migrations.AddPayouts do
  @moduledoc """
  Adds the payouts ledger and the payment stamping columns for the
  payout-execution engine (revenue rails, payout slice 1).
  """

  use Ecto.Migration

  def up do
    alter table(:payments) do
      add :paid_out_at, :utc_datetime_usec
      add :payout_id, :uuid
    end

    create table(:payouts, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :store_id, :uuid, null: false
      add :amount, :bigint, null: false
      add :currency, :text, null: false, default: "GHS"
      add :status, :text, null: false, default: "pending"
      add :recipient_code, :text
      add :transfer_code, :text
      add :transfer_reference, :text
      add :failure_reason, :text
      add :gateway_response, :map
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end
  end

  def down do
    drop table(:payouts)

    alter table(:payments) do
      remove :payout_id
      remove :paid_out_at
    end
  end
end
