defmodule Emakola.Themes.Sections do
  @moduledoc """
  Registry mapping section keys to modules across all sectionized themes,
  plus the `"block/<type>"` bridge into the page-builder library.
  Mirrors `Emakola.PageBuilder`'s registry pattern.
  """

  # Fan-out appends here, one module per decomposed theme.
  @sectionized_themes []

  def sectionized_themes, do: @sectionized_themes

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
    for theme <- @sectionized_themes,
        section <- theme.sections(),
        into: %{} do
      {section.key(), section}
    end
  end
end
