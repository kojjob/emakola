defmodule Emakola.Themes.Sections do
  @moduledoc """
  Registry mapping section keys to modules across all sectionized themes,
  plus the `"block/<type>"` bridge into the page-builder library.
  Mirrors `Emakola.PageBuilder`'s registry pattern.
  """

  # Fan-out appends here, one module per decomposed theme.
  @sectionized_themes [
    Emakola.Themes.Starter,
    Emakola.Themes.Atelier,
    Emakola.Themes.Market,
    # Born sectionized (2026-07-12) — built after the editor, so no retrofit.
    Emakola.Themes.Chale,
    Emakola.Themes.Dede,
    Emakola.Themes.Depot,
    Emakola.Themes.Fie,
    Emakola.Themes.Ntoma,
    Emakola.Themes.Akwaaba,
    Emakola.Themes.Pace,
    Emakola.Themes.Sika,
    # The legacy retrofit (2026-07-13) — the last nine. Registration is NOT
    # bookkeeping: a theme that implements sections/0 but is missing here
    # renders a BLANK storefront. resolve/1 fails on its own keys and
    # SectionRenderer skips every one of them, logging a warning nobody reads.
    # For Fashion, Beauty, Electronics and HomeLiving — whose nav lives inside
    # the hero section — it means the shop loses its navigation entirely.
    # SectionizedRegistrationTest holds that line so it can never happen again.
    Emakola.Themes.Beauty,
    Emakola.Themes.Bold,
    Emakola.Themes.Electronics,
    Emakola.Themes.Fashion,
    Emakola.Themes.Fresh,
    Emakola.Themes.HomeLiving,
    Emakola.Themes.Pharmacy,
    Emakola.Themes.Spotlight,
    Emakola.Themes.Vibrant,
    # Born sectionized (2026-07-25). Heirloom's nav is chrome rather than part
    # of its hero, so a missed registration here costs it its sections but not
    # its navigation — still a blank page, just a navigable one.
    Emakola.Themes.Heirloom,
    # Digital goods (2026-08-04) — registered in the SAME commit as
    # ThemeResolver, so the blank-storefront window never opens.
    Emakola.Themes.Adwuma
  ]

  @doc """
  All sectionized theme modules — the compile-time list plus the
  `extra_sectionized_themes` test seam, so this and `resolve/1` share one
  source of truth.
  """
  def sectionized_themes, do: @sectionized_themes ++ extra_sectionized_themes()

  @doc """
  Whether a theme module supports section editing (implements `sections/0`
  and is registered here). Gates the admin section editor — every other
  theme module has no `sections/0` and would crash callers.
  """
  def sectionized?(theme_module), do: theme_module in sectionized_themes()

  def resolve("block/" <> block_type) do
    case Emakola.PageBuilder.block_module_for(block_type) do
      nil ->
        :error

      block_module ->
        {:ok,
         {Emakola.Themes.Sections.BlockSection,
          %{block_type: block_type, block_module: block_module}}}
    end
  end

  def resolve(key) when is_binary(key) do
    case Map.fetch(theme_section_index(), key) do
      {:ok, module} -> {:ok, {module, %{}}}
      :error -> :error
    end
  end

  # Layouts written raw (migration, seed, direct Ash update) can hold entries
  # whose "type" is missing or non-binary. Fail closed here rather than at each
  # call site: callers already handle :error by degrading to a "Missing section"
  # row, and a guard that has to be remembered at every call site eventually
  # won't be.
  def resolve(_non_binary), do: :error

  defp theme_section_index do
    for theme <- sectionized_themes(),
        section <- theme.sections(),
        into: %{} do
      {section.key(), section}
    end
  end

  # Test-only seam: lets tests resolve section keys for a theme module that
  # isn't registered in @sectionized_themes yet (fan-out lands it for real
  # in later tasks). Not read outside test config.
  defp extra_sectionized_themes, do: Application.get_env(:emakola, :extra_sectionized_themes, [])
end
