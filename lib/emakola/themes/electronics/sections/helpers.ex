defmodule Emakola.Themes.Electronics.Sections.Helpers do
  @moduledoc """
  Shared helpers for Electronics section modules.

  `section_enabled?/2` is a second, legacy gate underneath the section
  editor's `enabled` flag (`Emakola.Themes.HomeSections`): a section entry
  can be enabled in the saved/default layout and still be hidden by the
  theme's older `@theme.sections.<name>` boolean (set via `theme_config`),
  preserving pre-section-editor behaviour for stores that toggled sections
  the old way.

  `setting/3` reads a merchant's section-editor override, falling back to
  the theme value the pre-section home already rendered.

  `slots/1` divides the catalogue between the home's product blocks so no
  product is shown twice.
  """

  def section_enabled?(theme, name) do
    case get_in(theme, [:sections, name]) do
      false -> false
      _ -> true
    end
  end

  def setting(settings, key, fallback) do
    case Map.get(settings || %{}, key) do
      value when is_binary(value) and value != "" -> value
      _ -> fallback
    end
  end

  def present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  def present(_value), do: nil

  @doc """
  How the home's product blocks divide the catalogue (`Emakola.Themes.Layout`)
  so no product is shown twice: the featured deal card takes the first
  product, the featured grid the next four, the immersive grid the four after
  that, and "more from the shop" three more. `unshown` is whatever no card
  carries — the immersive panel may borrow one of those photos, nothing else.
  """
  def slots(layout) do
    {featured_grid, rest} = Enum.split(layout.grid_products, 4)
    {immersive_grid, rest} = Enum.split(rest, 4)
    {more, unshown} = Enum.split(rest, 3)

    %{
      deal: layout.featured,
      featured_grid: featured_grid,
      immersive_grid: immersive_grid,
      more: more,
      unshown: unshown
    }
  end
end
