defmodule EmakolaWeb.AdminDesignConsistencyTest do
  @moduledoc """
  Pins the admin design system. Swept pages must use canonical components
  (admin_button/admin_card/status_pill) instead of hand-rolled markup.
  Pages join @swept as they are converted; the list only grows.
  """
  use ExUnit.Case, async: true

  @admin_dir "lib/emakola_web/live"

  # Page files converted to the design system (paths relative to @admin_dir)
  @swept ~w()

  # Raw classes forbidden in swept files — use canonical components/tokens.
  @forbidden ~w(bg-emerald-600 bg-emerald-700 bg-emakola-gold rounded-2xl rounded-xl)

  test "swept admin pages contain no hand-rolled design classes" do
    for rel <- @swept do
      source = File.read!(Path.join(@admin_dir, rel))

      for cls <- @forbidden do
        refute source =~ cls,
               "#{rel} contains raw `#{cls}` — use admin_button/admin_card/status_pill " <>
                 "or semantic tokens (docs/superpowers/specs/2026-06-10-admin-design-system-design.md)"
      end
    end
  end

  test "the Stitch token system stays dead" do
    hits =
      Path.wildcard("lib/**/*.{ex,heex}")
      |> Enum.filter(fn f ->
        File.read!(f) =~ ~r/(bg|text|border|ring)-(on-surface|surface-container)/
      end)

    assert hits == [], "Stitch-derived classes reappeared in: #{inspect(hits)}"
  end
end
