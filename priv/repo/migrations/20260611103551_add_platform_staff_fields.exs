defmodule Emakola.Repo.Migrations.AddPlatformStaffFields do
  @moduledoc """
  Adds platform-staff fields to users and retires is_platform_admin.

  Generated with `mix ash.codegen add_platform_staff_fields`, then
  hand-edited: the resource snapshots were stale (hand-written migrations
  had not been snapshotted since March), so everything except the users
  changes was removed — those tables/columns already exist in the database.
  The is_platform_admin copy/removal was added by hand because the stale
  snapshot never knew about that column.
  """

  use Ecto.Migration

  def up do
    alter table(:users) do
      add :is_owner, :boolean, null: false, default: false
      add :platform_permissions, {:array, :text}, null: false, default: []
      add :totp_secret, :binary
      add :totp_last_used_at, :utc_datetime_usec
      add :deactivated_at, :utc_datetime_usec
    end

    execute("UPDATE users SET is_owner = true WHERE is_platform_admin = true")

    alter table(:users) do
      remove :is_platform_admin
    end
  end

  def down do
    alter table(:users) do
      add :is_platform_admin, :boolean, null: false, default: false
    end

    execute("UPDATE users SET is_platform_admin = true WHERE is_owner = true")

    alter table(:users) do
      remove :deactivated_at
      remove :totp_last_used_at
      remove :totp_secret
      remove :platform_permissions
      remove :is_owner
    end
  end
end
