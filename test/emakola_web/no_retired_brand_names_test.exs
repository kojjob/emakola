defmodule EmakolaWeb.NoRetiredBrandNamesTest do
  @moduledoc """
  Vodafone Ghana became Telecel in 2023. "Vodafone Cash" is a retired brand —
  a shopper looking for their mobile-money network today is looking for
  "Telecel Cash", and copy that names a network that no longer exists reads as
  a platform that isn't maintained.

  The RENAME IS DISPLAY-ONLY, and this scan is deliberately case-sensitive:
  the lowercase `"vodafone"` stored value and the `VOD` settlement code are
  Paystack's API contract (verified against their Ghana mobile-money telco
  list: name has not migrated; code remains VOD) and MUST stay — renaming
  them would break subaccount creation and transfer recipients for every
  merchant on that network. Only the capital-V brand string is banned.
  """
  use ExUnit.Case, async: true

  @source_globs ["lib/**/*.ex", "lib/**/*.heex"]

  test "no user-facing copy names the retired Vodafone brand" do
    offenders =
      @source_globs
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.flat_map(fn path ->
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _n} -> String.contains?(line, "Vodafone") end)
        |> Enum.map(fn {_line, n} -> "#{path}:#{n}" end)
      end)

    assert offenders == [],
           """
           The Vodafone brand was retired in Ghana in 2023 — user-facing copy
           must say "Telecel Cash". (The lowercase "vodafone" stored value and
           the VOD gateway code are Paystack's contract and are fine.)

           Offending lines:
           #{Enum.map_join(offenders, "\n", &"  #{&1}")}
           """
  end
end
