defmodule Emakola.Repo.Migrations.AddTotalAttemptsToDeliveryProofs do
  @moduledoc """
  Makes the delivery-OTP attempt cap mean what it reads.

  `attempts` is reset to zero by `:reissue`, which is correct for its job: a
  buyer who fat-fingers a digit must not be locked out of the next code. But it
  meant the cap was per-CODE, not per-proof — reissuing bought a fresh window,
  so at three sends per ten minutes an attacker holding the fulfilment had
  fifteen guesses per ten minutes indefinitely, and the "5 attempts" cap bounded
  nothing over any real time horizon.

  `total_attempts` never resets, and `:reissue` refuses once it is spent.

  Backfilled from `attempts` rather than zero: existing rows have already spent
  the guesses recorded there, and starting them at zero would hand every proof
  in flight a free budget.
  """

  use Ecto.Migration

  def up do
    alter table(:fulfillment_delivery_proofs) do
      add(:total_attempts, :bigint, null: false, default: 0)
    end

    execute("UPDATE fulfillment_delivery_proofs SET total_attempts = attempts")
  end

  def down do
    alter table(:fulfillment_delivery_proofs) do
      remove(:total_attempts)
    end
  end
end
