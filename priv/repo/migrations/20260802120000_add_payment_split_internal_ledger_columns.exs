defmodule Emakola.Repo.Migrations.AddPaymentSplitInternalLedgerColumns do
  @moduledoc """
  Internal-rail ledger vocabulary on payment_splits ("one ledger, two rails",
  spec 2026-08-02):

  * settlement_method — :gateway_share (Paystack routed it at charge) vs
    :internal_hold (money stays in the platform account, owed via the ledger).
    Backfill: every historical row with a NULL subaccount_code is a :platform
    row, whose cut always stays in the main account — internal_hold.
  * currency — payouts partition by currency; Payment has it, splits did not.
  * paid_out_at / payout_id — the claim stamp, mirroring Payment's pair.
  * paid_amount — net frozen at claim time as amount - (reversed_amount -
    recovered_amount - reserved_recovery_amount): amount minus only the
    portion of any reversal not already recovered or reserved.
  * netted_reversal_amount — the no-double-claw fence: reversals already
    netted into a claim must not also be recovered from future earnings.

  Hand-written: mix ash.codegen is unusable in this repo (missing snapshots).
  """
  use Ecto.Migration

  def up do
    alter table(:payment_splits) do
      add(:settlement_method, :text, null: false, default: "gateway_share")
      add(:currency, :text, null: false, default: "GHS")
      add(:paid_out_at, :utc_datetime_usec)
      add(:payout_id, :uuid)
      add(:paid_amount, :bigint)
      add(:netted_reversal_amount, :bigint, null: false, default: 0)
    end

    execute("""
    UPDATE payment_splits SET settlement_method = 'internal_hold'
    WHERE subaccount_code IS NULL
    """)

    create(index(:payment_splits, [:recipient_store_id, :settlement_method, :paid_out_at]))
  end

  def down do
    drop(index(:payment_splits, [:recipient_store_id, :settlement_method, :paid_out_at]))

    alter table(:payment_splits) do
      remove(:settlement_method)
      remove(:currency)
      remove(:paid_out_at)
      remove(:payout_id)
      remove(:paid_amount)
      remove(:netted_reversal_amount)
    end
  end
end
