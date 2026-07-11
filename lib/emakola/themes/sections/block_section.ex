defmodule Emakola.Themes.Sections.BlockSection do
  @moduledoc """
  Bridges any registered page-builder block into the section system:
  key "block/<type>", settings = the block's content map. One adapter,
  the whole block library becomes insertable custom sections.
  """

  @behaviour Emakola.Themes.Section

  @impl true
  def key, do: "block/*"

  @impl true
  def label, do: "Builder block"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    %{block_type: block_type} = assigns.section_meta

    Emakola.PageBuilder.render_block(
      %{"type" => block_type, "content" => assigns.settings || %{}},
      %{
        __changed__: nil,
        store: assigns.store,
        products: assigns[:products] || [],
        categories: assigns[:categories] || []
      }
    )
  end
end
