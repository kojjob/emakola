defmodule EmakolaWeb.AdminDesignConsistencyTest do
  @moduledoc """
  Pins the admin design system. Swept pages must use canonical components
  (admin_button/admin_card/status_badge) instead of hand-rolled markup.
  Pages join @swept as they are converted; the list only grows.
  """
  use ExUnit.Case, async: true

  @admin_dir "lib/emakola_web/live"

  # Page files converted to the design system (paths relative to @admin_dir)
  @swept ~w(dashboard_live.ex admin/product_live/index.ex admin/order_live/index.ex admin/order_live/show.ex admin/inventory_live.ex admin/supplier_live/index.ex admin/supplier_live/show.ex admin/settings_live.ex admin/theme_live.ex admin/coupon_live.ex)

  # Raw classes forbidden in swept files — use canonical components/tokens.
  @forbidden ~w(bg-emerald-600 bg-emerald-700 bg-emakola-gold rounded-2xl rounded-xl)

  test "swept admin pages contain no hand-rolled design classes" do
    for rel <- @swept do
      source = File.read!(Path.join(@admin_dir, rel))

      for cls <- @forbidden do
        refute source =~ cls,
               "#{rel} contains raw `#{cls}` — use admin_button/admin_card/status_badge " <>
                 "or semantic tokens (docs/superpowers/specs/2026-06-10-admin-design-system-design.md)"
      end
    end
  end

  test "flash messages stack above modals" do
    # A flash raised from inside a modal (\"Could not send the invite email.\")
    # was painted over by the modal's blurred backdrop: both sat at z-50, so
    # DOM order decided, and the modal renders last. Found on production
    # 2026-08-23. The flash must outrank the modal numerically — equal
    # z-index is the bug, not a tie.
    flash_z = z_index!("lib/emakola_web/components/layouts.ex", ~r/id=\{@id\}[^>]*?z-\[?(\d+)/s)

    modal_z =
      z_index!("lib/emakola_web/components/core_components.ex", ~r/hidden relative z-\[?(\d+)/)

    assert flash_z > modal_z,
           "flash group is z-#{flash_z} but the modal is z-#{modal_z} — a flash raised " <>
             "from inside a modal renders behind its backdrop and is never seen"
  end

  defp z_index!(path, regex) do
    source = File.read!(path)

    case Regex.run(regex, source, capture: :all_but_first) do
      [value] -> String.to_integer(value)
      _ -> flunk("could not find a z-index in #{path} with #{inspect(regex)}")
    end
  end

  test "no admin page styles its own stat tiles" do
    # The tile's look lives in stat_card and is chosen with one `tone`. A page
    # that passes its own icon_bg — or colours the icon inside the slot — is
    # how five pages ended up with five different tiles.
    offenders =
      "lib/emakola_web/live/**/*.ex"
      |> Path.wildcard()
      |> Enum.filter(fn file ->
        source = File.read!(file)
        String.contains?(source, "stat_card") and String.contains?(source, ~s(icon_bg=))
      end)

    assert offenders == [],
           "these pages style their own stat tiles instead of passing a tone: " <>
             inspect(offenders)
  end

  test "stat tile icons are Heroicons, never hand-rolled SVG" do
    # The tile paints its own 56px chip and forces text-white. An inline
    # <svg class="w-5 h-5 text-slate-600"> ignores both: it renders at 20px in
    # its own colour inside the chip. Inventory shipped four of them.
    offenders =
      "lib/emakola_web/live/**/*.ex"
      |> Path.wildcard()
      |> Enum.filter(fn file ->
        # Bounded to ONE slot: an unbounded `.*?` matches an <:icon> here and an
        # <svg> two hundred lines later in a table cell, which named five
        # innocent pages the first time this ran.
        File.read!(file) =~ ~r/<:icon>(?:(?!<\/:icon>).)*<svg/s
      end)

    assert offenders == [],
           "these pages put a raw <svg> in a stat tile's :icon slot — use " <>
             "<.icon name=\"hero-*\" class=\"size-7\" /> so the tile can colour " <>
             "and size it: " <> inspect(offenders)
  end

  test "every stat tile declares a tone" do
    # A tile with no `tone` falls to neutral, so two of them in one row are
    # the same grey and carry no meaning. This is the single most repeated
    # piece of feedback on the admin: "the cards are the same colour."
    offenders =
      "lib/emakola_web/live/**/*.ex"
      |> Path.wildcard()
      |> Enum.map(fn file ->
        source = File.read!(file)
        tiles = source |> String.split("<.stat_card") |> length() |> Kernel.-(1)
        toned = source |> String.split(~r/<\.stat_card[^>]*?\stone=/s) |> length() |> Kernel.-(1)
        {file, tiles, toned}
      end)
      |> Enum.filter(fn {_file, tiles, toned} -> tiles > 0 and toned < tiles end)
      |> Enum.map(fn {file, tiles, toned} -> "#{file} (#{tiles - toned} of #{tiles} untoned)" end)

    assert offenders == [],
           "these pages render a stat tile without a tone, so it greys out and " <>
             "reads the same as its neighbour: " <> Enum.join(offenders, ", ")
  end

  test "every admin page header carries an icon badge" do
    # The badge is how a page identifies itself at a glance — the merchants
    # using this admin often scan the picture, not the heading.
    offenders =
      "lib/emakola_web/live/**/*.ex"
      |> Path.wildcard()
      |> Enum.map(fn file ->
        source = File.read!(file)
        headers = source |> String.split("<.admin_page_header") |> length() |> Kernel.-(1)

        iconed =
          source
          |> String.split(~r/<\.admin_page_header(?:(?!\/>|>).)*?\sicon=/s)
          |> length()
          |> Kernel.-(1)

        {file, headers, iconed}
      end)
      |> Enum.filter(fn {_file, headers, iconed} -> headers > 0 and iconed < headers end)
      |> Enum.map(fn {file, _h, _i} -> file end)

    assert offenders == [],
           "these page headers have no icon badge: " <> Enum.join(offenders, ", ")
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
