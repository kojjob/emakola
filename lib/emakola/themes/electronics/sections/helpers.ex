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
end
