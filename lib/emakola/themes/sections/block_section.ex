defmodule Emakola.Themes.Sections.BlockSection do
  @moduledoc false
  @behaviour Emakola.Themes.Section

  @impl true
  def key, do: "block/*"
  @impl true
  def label, do: "Builder block"
  @impl true
  def settings_schema, do: []
  @impl true
  def render(assigns), do: raise("implemented in Task 2: #{inspect(assigns[:section_meta])}")
end
