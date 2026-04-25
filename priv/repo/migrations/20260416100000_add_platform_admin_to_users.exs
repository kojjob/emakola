defmodule Emakola.Repo.Migrations.AddPlatformAdminToUsers do
  @moduledoc """
  Adds is_platform_admin boolean to users table.

  Platform admins can access /platform/* routes to manage all stores,
  view platform-wide metrics, and administer merchant subscriptions.
  Default is false — platform admin status is granted via mix task.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_platform_admin, :boolean, default: false, null: false
    end
  end
end
