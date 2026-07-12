defmodule Emakola.Themes.Sections.BlockSection do
  @moduledoc """
  Bridges any registered page-builder block into the section system:
  key "block/<type>", settings = the block's content map. One adapter,
  the whole block library becomes insertable custom sections.

  Layout sanitization (`Emakola.Themes.HomeSections.sanitize_entry/2`) keeps
  only scalar (string/boolean/integer) settings values — list/map-valued
  block content (e.g. FAQ items, testimonial lists) is dropped on write. A
  bridged block with such fields renders its built-in defaults for them
  instead of the merchant's content. The section editor should not offer
  those fields on `block/<type>` entries until list/map values are
  supported end-to-end.
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
