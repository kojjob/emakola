defmodule Emakola.Repo.Migrations.CreateEarnSalesShares do
  use Ecto.Migration

  def change do
    create table(:earn_sales_shares, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false

      add :listing_id, references(:reseller_listings, type: :uuid, on_delete: :delete_all),
        null: false

      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false
      add :token, :text, null: false
      add :channel, :text, null: false
      add :click_count, :bigint, null: false, default: 0
      add :share_count, :bigint, null: false, default: 0
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_sales_shares, [:token])
    create unique_index(:earn_sales_shares, [:listing_id, :channel])

    create constraint(:earn_sales_shares, :valid_channel,
             check: "channel IN ('whatsapp', 'facebook', 'copy_link')"
           )

    create constraint(:earn_sales_shares, :non_negative_share_stats,
             check: "click_count >= 0 AND share_count >= 0"
           )

    create table(:earn_sales_share_conversions, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :share_id, references(:earn_sales_shares, type: :uuid, on_delete: :delete_all),
        null: false

      add :order_id, references(:orders, type: :uuid, on_delete: :delete_all), null: false
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :revenue, :bigint, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_sales_share_conversions, [:order_id])
    create index(:earn_sales_share_conversions, [:share_id])

    create constraint(:earn_sales_share_conversions, :non_negative_conversion_revenue,
             check: "revenue >= 0"
           )
  end
end
