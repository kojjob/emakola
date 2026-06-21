defmodule Emakola.Repo.Migrations.CreateMerchantIdentities do
  @moduledoc """
  Backing table for Emakola.Accounts.MerchantIdentity (AshAuthentication
  UserIdentity extension) — stores merchants' linked OAuth identities.

  Hand-written: this project's ash.codegen snapshots are stale (see
  LAUNCH_TODO.md), so migrations are authored by hand. Columns + the
  [user_id, uid, strategy] unique identity mirror the extension's schema.
  """

  use Ecto.Migration

  def up do
    create table(:merchant_identities, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :user_id,
          references(:merchants,
            column: :id,
            name: "merchant_identities_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :strategy, :text, null: false
      add :uid, :text, null: false
      add :access_token, :text
      add :refresh_token, :text
      add :access_token_expires_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:merchant_identities, [:user_id, :uid, :strategy],
             name: "merchant_identities_uid_strategy_index"
           )
  end

  def down do
    drop constraint(:merchant_identities, "merchant_identities_user_id_fkey")

    drop_if_exists unique_index(:merchant_identities, [:user_id, :uid, :strategy],
                     name: "merchant_identities_uid_strategy_index"
                   )

    drop table(:merchant_identities)
  end
end
