defmodule Emakola.Repo.Migrations.CreateDownloadGrants do
  @moduledoc """
  Creates `download_grants` — customer entitlements to download a specific
  `digital_files` row, issued when an order is paid. One row per
  (line_item, digital_file) pair.

  `customer_id` is nullable for guest-checkout orders (we still want to
  issue a grant; delivery happens via signed email link rather than the
  customer account page).

  `download_limit` and `expires_at` are both nullable: nil means
  unlimited / never. The download endpoint enforces both at delivery
  time; this table is purely state.
  """
  use Ecto.Migration

  def change do
    create table(:download_grants, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false

      add :order_id, references(:orders, type: :uuid, on_delete: :delete_all), null: false

      add :line_item_id, references(:line_items, type: :uuid, on_delete: :delete_all), null: false

      add :customer_id, references(:customers, type: :uuid, on_delete: :nilify_all)

      add :digital_file_id, references(:digital_files, type: :uuid, on_delete: :delete_all),
        null: false

      add :download_limit, :integer
      add :downloaded_count, :integer, null: false, default: 0
      add :expires_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:download_grants, [:store_id, :customer_id])
    create index(:download_grants, [:store_id, :order_id])
    create unique_index(:download_grants, [:line_item_id, :digital_file_id])
  end
end
