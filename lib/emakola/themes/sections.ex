defmodule Emakola.Themes.Sections do
  @moduledoc """
  Registry mapping section keys to modules across all sectionized themes,
  plus the `"block/<type>"` bridge into the page-builder library.
  Mirrors `Emakola.PageBuilder`'s registry pattern.
  """

  # Fan-out appends here, one module per decomposed theme.
  @sectionized_themes [Emakola.Themes.Starter, Emakola.Themes.Atelier]

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
