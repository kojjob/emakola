defmodule Emakola.SeedsNoDuplicateFlagsTest do
  @moduledoc """
  `priv/repo/seeds.exs` must not create a feature flag a migration already
  inserts.

  `feature_flags.key` is unique and the seed file uses `Ash.create!`, so a
  duplicate raises and takes the *whole* seed run down with it. CI runs
  `mix ecto.migrate` and then this file before starting the server for the
  Playwright suite, so the blast radius is not one flag: seeding stops, no
  merchant user is created, `auth.setup.ts` cannot sign in, and all sixty-odd
  browser tests fail on a change that never touched them.

  A source check rather than a database one, so it runs anywhere and names
  the offending key.
  """
  use ExUnit.Case, async: true

  @seeds "priv/repo/seeds.exs"
  @migrations Path.wildcard("priv/repo/migrations/*.exs")

  test "no flag key is created by both a migration and the seed file" do
    migration_keys = migration_flag_keys()

    # A scan that silently matched nothing would make the assertion below pass
    # while proving nothing — which is exactly what the first version of this
    # test did, because the migration writes '#{@key}' rather than a literal.
    assert MapSet.size(migration_keys) > 0,
           "no flag keys extracted from migrations; the scan is stale"

    seed_keys =
      ~r/key:\s*"([a-z0-9_]+)"/
      |> Regex.scan(File.read!(@seeds))
      |> Enum.map(&Enum.at(&1, 1))
      |> MapSet.new()

    clashes = MapSet.intersection(migration_keys, seed_keys)

    assert MapSet.size(clashes) == 0,
           """
           These feature flag keys are created by BOTH a migration and #{@seeds}:

           #{Enum.map_join(clashes, "\n", &"  - #{&1}")}

           feature_flags.key is unique and seeds.exs uses Ash.create!, so the
           second write raises and aborts the entire seed run. Keep the
           migration (it runs in production too) and drop the seed entry.
           """
  end

  test "the scan finds the key the featuring-floor migration inserts" do
    assert "directory_featuring_floor" in migration_flag_keys()
  end

  # Keys a migration writes into feature_flags. Handles both a literal in the
  # SQL and the `@key "..."` module attribute the SQL interpolates.
  defp migration_flag_keys do
    @migrations
    |> Enum.flat_map(fn path ->
      body = File.read!(path)

      if String.contains?(body, "INSERT INTO feature_flags") do
        literals = Regex.scan(~r/'([a-z0-9_]{4,})'/, body) |> Enum.map(&Enum.at(&1, 1))
        attrs = Regex.scan(~r/@key\s+"([a-z0-9_]+)"/, body) |> Enum.map(&Enum.at(&1, 1))
        literals ++ attrs
      else
        []
      end
    end)
    |> MapSet.new()
  end
end
