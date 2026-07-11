defmodule Emakola.Repo.Migrations.CreatePartnerCreditAgreements do
  use Ecto.Migration

  def change do
    create table(:partner_credit_offers, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :provider_type, :text, null: false
      add :provider_store_id, :uuid
      add :provider_name, :text, null: false
      add :license_reference, :text
      add :creditor_subaccount_code, :text, null: false
      add :borrower_store_id, :uuid, null: false
      add :minimum_tier, :text, null: false
      add :principal_amount, :bigint, null: false
      add :fee_amount, :bigint, null: false
      add :repayment_bps, :integer, null: false
      add :term_days, :integer, null: false
      add :reason_code, :text, null: false
      add :decision_snapshot, :map, null: false, default: %{}
      add :status, :text, null: false, default: "offered"
      timestamps(type: :utc_datetime_usec)
    end

    create table(:partner_credit_agreements, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :offer_id, references(:partner_credit_offers, type: :uuid, on_delete: :restrict),
        null: false

      add :borrower_store_id, :uuid, null: false
      add :passport_id, :uuid, null: false
      add :principal_amount, :bigint, null: false
      add :fee_amount, :bigint, null: false
      add :total_due, :bigint, null: false
      add :outstanding_amount, :bigint, null: false
      add :repayment_bps, :integer, null: false
      add :consent_snapshot, :map, null: false
      add :consented_at, :utc_datetime_usec, null: false
      add :external_disbursement_reference, :text
      add :activated_at, :utc_datetime_usec
      add :status, :text, null: false, default: "accepted"
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:partner_credit_agreements, [:offer_id])

    create table(:partner_credit_repayments, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :agreement_id,
          references(:partner_credit_agreements, type: :uuid, on_delete: :restrict), null: false

      add :payment_id, references(:payments, type: :uuid, on_delete: :restrict), null: false
      add :amount, :bigint, null: false
      add :reversed_amount, :bigint, null: false, default: 0
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:partner_credit_repayments, [:agreement_id, :payment_id])

    alter table(:payment_splits) do
      add :credit_agreement_id,
          references(:partner_credit_agreements, type: :uuid, on_delete: :restrict)
    end

    create index(:payment_splits, [:credit_agreement_id])
  end
end
