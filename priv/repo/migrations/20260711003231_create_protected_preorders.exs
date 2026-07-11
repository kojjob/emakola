defmodule Emakola.Repo.Migrations.CreateProtectedPreorders do
  use Ecto.Migration

  def change do
    create table(:protected_preorders, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :supplier_store_id, :uuid, null: false
      add :listing_variant_id, :uuid, null: false
      add :title, :text, null: false
      add :description, :text, null: false
      add :unit_price, :bigint, null: false
      add :deposit_amount, :bigint, null: false
      add :minimum_quantity, :integer, null: false
      add :maximum_quantity, :integer, null: false
      add :committed_quantity, :integer, null: false, default: 0
      add :commitment_deadline, :utc_datetime_usec, null: false
      add :delivery_window_start, :date, null: false
      add :delivery_window_end, :date, null: false
      add :automatic_refund_deadline, :utc_datetime_usec, null: false
      add :customer_disclosures, :map, null: false
      add :legal_approval_reference, :text
      add :payment_provider_approval_reference, :text
      add :status, :text, null: false, default: "draft"
      add :failed_at, :utc_datetime_usec
      add :failure_reason, :text
      timestamps(type: :utc_datetime_usec)
    end

    create index(:protected_preorders, [:supplier_store_id, :status])

    create table(:preorder_milestones, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :preorder_id, references(:protected_preorders, type: :uuid, on_delete: :delete_all),
        null: false

      add :position, :integer, null: false
      add :title, :text, null: false
      add :due_at, :utc_datetime_usec, null: false
      add :evidence_requirements, :text, null: false
      add :status, :text, null: false, default: "pending"
      add :evidence, :map, null: false, default: %{}
      add :completed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:preorder_milestones, [:preorder_id, :position])

    create table(:preorder_deposits, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :preorder_id, references(:protected_preorders, type: :uuid, on_delete: :restrict),
        null: false

      add :store_id, :uuid, null: false
      add :customer_id, :uuid, null: false
      add :payment_id, references(:payments, type: :uuid, on_delete: :restrict)
      add :quantity, :integer, null: false
      add :amount, :bigint, null: false
      add :status, :text, null: false, default: "pending"
      add :refund_claimed_at, :utc_datetime_usec
      add :refund_reference, :text
      add :refund_error, :text
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:preorder_deposits, [:payment_id], where: "payment_id IS NOT NULL")
    create index(:preorder_deposits, [:preorder_id, :status])
  end
end
