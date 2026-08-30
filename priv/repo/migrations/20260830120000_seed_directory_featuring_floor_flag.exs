defmodule Emakola.Repo.Migrations.SeedDirectoryFeaturingFloorFlag do
  @moduledoc """
  Puts the directory featuring floor's switch on /platform/settings.

  `Emakola.Stores.featuring_floor_enforced?/0` reads this flag, and a missing
  row already reads as "floor off" — which is the state a young directory
  wants. The row exists so the project owner can find the switch and turn the
  floor back ON without inventing the key by hand.

  Data only, and idempotent: `ON CONFLICT DO NOTHING` means a re-run never
  overwrites a decision the owner has since made in the UI.
  """

  use Ecto.Migration

  @key "directory_featuring_floor"

  def up do
    execute("""
    INSERT INTO feature_flags (id, key, name, description, enabled)
    VALUES (
      gen_random_uuid(),
      '#{@key}',
      'Directory featuring floor',
      'ON: a shop must clear the merit floor — photo, description, contact, region, 3 items, verified payout, recent activity, clean conduct — to hold a featured slot on /stores. OFF: every active shop competes on score alone. Keep it off while payouts are dark, or the nightly run disqualifies everyone and the /stores hero disappears.',
      false
    )
    ON CONFLICT (key) DO NOTHING
    """)
  end

  def down do
    execute("DELETE FROM feature_flags WHERE key = '#{@key}'")
  end
end
