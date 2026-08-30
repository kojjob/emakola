defmodule Emakola.Themes.ImagesFillCardsTest do
  @moduledoc """
  Product imagery fills its frame. No letterboxing.

  Electronics and Pharmacy drew product photos with `object-contain p-4` (and
  `p-8` on the detail page), so a photo sat shrunk inside a grey box with air
  around it — on a card, in the hero rail, and on the product page. Against
  real merchant photography that reads as a broken or half-loaded image, which
  is exactly how it was reported.

  A logo is the one exception and is asserted rather than merely skipped: a
  wordmark cropped to fill is a mangled brand, so `object-contain` is correct
  there and must stay.
  """
  use ExUnit.Case, async: true

  # Every theme file, not a hand-list — a theme added tomorrow is covered.
  @theme_files Path.wildcard("lib/emakola/themes/**/*.ex")

  # The Atelier nav renders the merchant's logo, where containing is right.
  @logo_exceptions ["lib/emakola/themes/atelier/nav.ex"]

  # Every way a photo can end up shrunk inside its frame, not just the one
  # Electronics used. A later theme reaching for `bg-contain` or an inline
  # `object-fit: contain` is the same bug wearing different clothes.
  @letterboxing [
    "object-contain",
    "object-scale-down",
    "object-none",
    "bg-contain",
    "background-size: contain",
    "object-fit: contain"
  ]

  test "no theme letterboxes a product photo" do
    offenders =
      for path <- @theme_files,
          path not in @logo_exceptions,
          body = File.read!(path),
          hit = Enum.find(@letterboxing, &String.contains?(body, &1)),
          do: "#{path} (#{hit})"

    assert offenders == [],
           """
           These theme files letterbox an image:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}

           Product imagery fills its frame (`object-cover`). If this is a logo,
           add the file to @logo_exceptions with a note saying why.
           """
  end

  test "the logo exception is real, not a stale entry" do
    for path <- @logo_exceptions do
      assert File.exists?(path), "#{path} is listed as a logo exception but does not exist"

      body = File.read!(path)

      assert Enum.any?(@letterboxing, &String.contains?(body, &1)),
             "#{path} no longer letterboxes anything — drop it from @logo_exceptions"
    end
  end

  test "the sweep actually covers every theme, not a stale glob" do
    theme_dirs =
      "lib/emakola/themes/*"
      |> Path.wildcard()
      |> Enum.filter(&File.dir?/1)
      |> Enum.map(&Path.basename/1)

    # More than twenty themes ship today; a glob that silently matched three
    # files would pass this suite while proving nothing.
    assert length(theme_dirs) > 15
    assert length(@theme_files) > 100

    for dir <- theme_dirs do
      assert Enum.any?(@theme_files, &String.contains?(&1, "/themes/#{dir}/")),
             "the sweep missed the #{dir} theme entirely"
    end
  end
end
