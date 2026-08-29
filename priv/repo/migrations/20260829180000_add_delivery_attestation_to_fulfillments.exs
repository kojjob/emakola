defmodule Emakola.Repo.Migrations.AddDeliveryAttestationToFulfillments do
  @moduledoc """
  Records whether a delivery was proven or merely claimed.

  Delivery is what starts the merchant's payout clock, and there are two very
  different ways to reach it. One requires the buyer to read out a code they
  alone hold. The other is the merchant pressing a button. Until now the
  resulting row looked identical, so neither the merchant's own order page nor
  the platform's protection queue could tell them apart.

  The self-attest path is kept rather than removed: `release_after` is stamped
  only on delivery, so there is no auto-release timer, and a merchant whose
  buyer never answers the phone would otherwise wait for the 30-day stale-hold
  sweep and manual staff review. Removing the escape hatch would punish honest
  merchants for their customers' silence. Making it legible costs nothing.

  Existing rows default to `false` — unverified — on purpose. Every delivery
  recorded before this migration was marked either by a merchant's own hand or
  by an OTP, and we cannot now tell which. Calling them all unproven is the
  honest reading and the safe one; calling them proven would fabricate evidence
  that was never collected.
  """

  use Ecto.Migration

  def up do
    alter table(:fulfillments) do
      add(:delivery_verified, :boolean, null: false, default: false)
      add(:delivery_attested_by_id, :uuid)
      add(:delivery_attested_at, :utc_datetime_usec)
    end

    create(
      index(:fulfillments, [:delivery_verified],
        where: "status = 'delivered' AND delivery_verified = false",
        name: "fulfillments_unverified_delivery_index"
      )
    )
  end

  def down do
    drop(
      index(:fulfillments, [:delivery_verified], name: "fulfillments_unverified_delivery_index")
    )

    alter table(:fulfillments) do
      remove(:delivery_verified)
      remove(:delivery_attested_by_id)
      remove(:delivery_attested_at)
    end
  end
end
