defmodule Emakola.Themes.Starter.Sections.Helpers do
  @moduledoc """
  Shared helpers for Starter section modules.

  `section_enabled?/2` is a second, legacy gate underneath the section
  editor's `enabled` flag (`Emakola.Themes.HomeSections`): a section entry
  can be enabled in the saved/default layout and still be hidden by the
  theme's older `@theme.sections.<name>` boolean (set via `theme_config`),
  preserving pre-section-editor behaviour for stores that toggled sections
  the old way.
  """

  def section_enabled?(theme, section_name) do
    case theme do
      %{sections: sections} when is_map(sections) ->
        Map.get(sections, section_name, true)

      _ ->
        true
    end
  end
end
