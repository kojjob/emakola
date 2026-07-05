defmodule EmakolaWeb.StorefrontDesignConsistencyTest do
  @moduledoc """
  Pins the storefront theme-token contract. Shared storefront components
  must use theme tokens (store-accent / cta-dark / store-bg families) or
  standard palette classes — never raw hex. Merchant-controlled colors
  reach CSS only through CssColor.safe_css_color/2.
  """
  use ExUnit.Case, async: true

  @swept_files [
    "lib/emakola_web/components/storefront_components.ex",
    "lib/emakola_web/components/stores_components.ex"
  ]

  # The scan covers the FULL file content (including dynamic `fill={...}`
  # attributes, style strings, comments, and moduledocs) so nothing slips
  # through line-shape gaps. Every allowed literal is listed explicitly,
  # exact-case, grouped by why it is allowed:
  #
  # Pictorial Ghana-map art in stores_components.ex — geographic colors,
  # not theme-followers. One entry per allowed literal.
  @map_art_hexes ~w(#fef3c7 #7A1F1F #059669 #d4a843 #065f46 #1f2937 #ffffff)

  # Safe fallback defaults passed to CssColor.safe_css_color/2 and
  # resolve_color/3 in stores_components.ex — these ARE the sanctioned
  # values merchant colors fall back to, so they must appear in source.
  @fallback_hexes ~w(#B45309 #1C1917 #1F2937 #0EA5E9)

  # Design-language prose in the storefront_components.ex @moduledoc —
  # documentation describing the palette, never rendered as CSS.
  @prose_hexes ~w(#FAFAF9)

  @allowlist @map_art_hexes ++ @fallback_hexes ++ @prose_hexes

  test "swept storefront components contain no unapproved hex colors" do
    for file <- @swept_files do
      source = File.read!(file)

      hexes =
        Regex.scan(~r/#[0-9a-fA-F]{3,8}\b/, source)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.reject(&(&1 in @allowlist))

      assert hexes == [],
             "#{file} contains raw hex #{inspect(hexes)} — use theme tokens " <>
               "(store-accent/cta-dark/store-bg) or standard palette classes. " <>
               "See docs/superpowers/specs/2026-06-10-storefront-theme-tokens-design.md"
    end
  end

  test "the theme-var contract root stays intact" do
    layout = File.read!("lib/emakola_web/components/layouts/storefront.html.heex")
    assert layout =~ "--theme-primary", "storefront layout must inject --theme-primary"
    assert layout =~ "safe_css_color", "layout color injection must go through CssColor"

    css = File.read!("assets/css/app.css")

    assert css =~ "--color-store-accent: var(--theme-primary",
           "app.css must bridge --color-store-accent to --theme-primary"
  end
end
