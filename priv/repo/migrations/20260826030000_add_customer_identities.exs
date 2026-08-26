defmodule Emakola.Repo.Migrations.AddCustomerIdentities do
  @moduledoc """
  Per-store social identities for shoppers.

  Unique on `(store_id, strategy, uid)`, NOT on `(strategy, uid)` like
  `merchant_identities`. The same Google account is a different customer at every
  shop they buy from, so global uniqueness would make the second shop's sign-in
  collide with the first. Ash generates the store_id column into the index itself:
  an identity on a multitenant resource defaults to `all_tenants?: false`.

  Hand-written rather than left as generated — `ash_postgres.generate_migrations`
  emits the whole schema in this project, so the generated file also tried to
  recreate tables that already exist.
  """
  use Ecto.Migration

  def up do
    create table(:customer_identities, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:store_id, :uuid, null: false)
      add(:uid, :text, null: false)
      add(:strategy, :text, null: false)
      add(:access_token, :text)
      add(:access_token_expires_at, :utc_datetime_usec)
      add(:refresh_token, :text)

      add(
        :user_id,
        references(:customers,
          column: :id,
          name: "customer_identities_user_id_fkey",
          type: :uuid,
          prefix: "public",
          on_delete: :delete_all
        )
      )
    end

    create(
      unique_index(:customer_identities, [:store_id, :strategy, :uid],
        name: "customer_identities_uid_strategy_index"
      )
    )
  end

  def down do
    drop_if_exists(
      index(:customer_identities, [:store_id, :strategy, :uid],
        name: "customer_identities_uid_strategy_index"
      )
    )

    drop_if_exists(table(:customer_identities))
  end
end
