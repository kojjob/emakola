defmodule Emakola.Repo.Migrations.BackfillDefaultThemeConfig do
  @moduledoc """
  Stores with empty `theme_config` (`{}`) bypass the theme renderer
  delegation, surfacing as missing navbars and stale layouts on the
  storefront. The application code falls back to `Market` when no
  theme is set, but the storefront layout reads `assigns[:theme_module]`
  which is only assigned when a theme exists in `theme_config`.

  This migration backfills `theme_config = %{"theme_id" => "starter"}`
  for any store whose theme_config is the empty map. Stores that have
  intentionally configured a theme are not touched.

  Idempotent — re-running on rows that already have a theme_id is a
  no-op.
  """
  use Ecto.Migration

  def up do
    execute("""
    UPDATE stores
    SET theme_config = jsonb_set(theme_config, '{theme_id}', '"starter"')
    WHERE theme_config = '{}'::jsonb OR NOT (theme_config ? 'theme_id')
    """)
  end

  def down do
    # No-op on rollback — we don't want to wipe a merchant's chosen theme
    # just because we rolled the migration back.
    :ok
  end
end
