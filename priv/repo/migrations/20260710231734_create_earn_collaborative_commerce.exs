defmodule Emakola.Repo.Migrations.CreateEarnCollaborativeCommerce do
  use Ecto.Migration

  def change do
    create table(:earn_group_buy_campaigns, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false

      add :listing_id, references(:reseller_listings, type: :uuid, on_delete: :restrict),
        null: false

      add :listing_variant_id,
          references(:reseller_listing_variants, type: :uuid, on_delete: :restrict), null: false

      add :title, :text, null: false
      add :threshold_quantity, :integer, null: false
      add :committed_quantity, :integer, null: false, default: 0
      add :unit_price, :bigint, null: false
      add :deadline, :utc_datetime_usec, null: false
      add :refund_deadline, :utc_datetime_usec, null: false
      add :status, :text, null: false, default: "draft"
      add :terms, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create index(:earn_group_buy_campaigns, [:store_id, :status])

    create constraint(:earn_group_buy_campaigns, :group_buy_threshold_positive,
             check: "threshold_quantity > 1"
           )

    create constraint(:earn_group_buy_campaigns, :group_buy_price_positive,
             check: "unit_price > 0"
           )

    create constraint(:earn_group_buy_campaigns, :group_buy_quantity_valid,
             check: "committed_quantity >= 0 AND committed_quantity <= threshold_quantity"
           )

    create constraint(:earn_group_buy_campaigns, :group_buy_dates_valid,
             check: "refund_deadline >= deadline"
           )

    create constraint(:earn_group_buy_campaigns, :group_buy_status_valid,
             check: "status IN ('draft', 'open', 'funded', 'fulfilled', 'cancelled', 'refunded')"
           )

    create table(:earn_group_buy_commitments, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :campaign_id,
          references(:earn_group_buy_campaigns, type: :uuid, on_delete: :delete_all), null: false

      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :customer_id, references(:customers, type: :uuid, on_delete: :nilify_all)
      add :payment_id, references(:payments, type: :uuid, on_delete: :nilify_all)
      add :quantity, :integer, null: false
      add :amount, :bigint, null: false
      add :status, :text, null: false, default: "pending"
      timestamps(type: :utc_datetime_usec)
    end

    create index(:earn_group_buy_commitments, [:campaign_id, :status])

    create unique_index(:earn_group_buy_commitments, [:payment_id],
             where: "payment_id IS NOT NULL"
           )

    create constraint(:earn_group_buy_commitments, :group_buy_commitment_quantity_positive,
             check: "quantity > 0"
           )

    create constraint(:earn_group_buy_commitments, :group_buy_commitment_amount_positive,
             check: "amount > 0"
           )

    create constraint(:earn_group_buy_commitments, :group_buy_commitment_status_valid,
             check: "status IN ('pending', 'paid', 'cancelled', 'refunded')"
           )

    create table(:earn_sales_teams, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :status, :text, null: false, default: "active"
      add :created_by_id, references(:merchants, type: :uuid, on_delete: :restrict), null: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:earn_sales_teams, [:store_id, :status])

    create constraint(:earn_sales_teams, :sales_team_status_valid,
             check: "status IN ('active', 'closed')"
           )

    create table(:earn_sales_team_members, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :team_id, references(:earn_sales_teams, type: :uuid, on_delete: :delete_all),
        null: false

      add :merchant_id, references(:merchants, type: :uuid, on_delete: :delete_all), null: false
      add :role, :text, null: false
      add :split_bps, :integer, null: false
      add :status, :text, null: false, default: "invited"
      add :consented_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_sales_team_members, [:team_id, :merchant_id])

    create constraint(:earn_sales_team_members, :sales_team_role_valid,
             check: "role IN ('owner', 'content', 'seller', 'support')"
           )

    create constraint(:earn_sales_team_members, :sales_team_split_valid,
             check: "split_bps BETWEEN 0 AND 10000"
           )

    create constraint(:earn_sales_team_members, :sales_team_member_status_valid,
             check: "status IN ('invited', 'active', 'declined', 'removed')"
           )

    create table(:earn_franchise_packages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :supplier_store_id, references(:stores, type: :uuid, on_delete: :delete_all),
        null: false

      add :name, :text, null: false
      add :offer_ids, {:array, :uuid}, null: false, default: []
      add :training, :map, null: false, default: %{}
      add :brand_rules, :map, null: false, default: %{}
      add :channel_permissions, {:array, :text}, null: false, default: []
      add :territory, :text
      add :commission_bps, :integer, null: false
      add :status, :text, null: false, default: "draft"
      timestamps(type: :utc_datetime_usec)
    end

    create index(:earn_franchise_packages, [:supplier_store_id, :status])

    create constraint(:earn_franchise_packages, :franchise_commission_valid,
             check: "commission_bps BETWEEN 1 AND 10000"
           )

    create constraint(:earn_franchise_packages, :franchise_status_valid,
             check: "status IN ('draft', 'published', 'paused', 'archived')"
           )

    create table(:earn_franchise_enrollments, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :package_id, references(:earn_franchise_packages, type: :uuid, on_delete: :delete_all),
        null: false

      add :reseller_store_id, references(:stores, type: :uuid, on_delete: :delete_all),
        null: false

      add :status, :text, null: false, default: "applied"
      add :terms_accepted_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_franchise_enrollments, [:package_id, :reseller_store_id])

    create constraint(:earn_franchise_enrollments, :franchise_enrollment_status_valid,
             check: "status IN ('applied', 'approved', 'declined', 'suspended', 'ended')"
           )
  end
end
