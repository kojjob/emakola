defmodule Emakola.PageBuilder.Renderer do
  @moduledoc """
  Renders a built page by iterating its blocks and dispatching each to its
  registered block module.

  Lives separately from `Emakola.PageBuilder` so the registry/dispatcher
  module stays free of Phoenix.Component concerns. `StoreLive` calls
  `<.page page={...} store={...} products={...} categories={...} />`.
  """
  use Phoenix.Component

  alias Emakola.PageBuilder

  @doc """
  Renders every block on `page`, passing `store`, `products`, and `categories`
  through to each block's `render/1` callback. Unrecognised block types are
  silently skipped — the page keeps rendering even if a block module is
  removed or a stored block uses an unknown type.
  """
  attr :page, :map, required: true
  attr :store, :map, required: true
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def page(assigns) do
    assigns = assign(assigns, :blocks, assigns.page.blocks || [])

    ~H"""
    <%= for block <- @blocks do %>
      {PageBuilder.render_block(block, %{
        store: @store,
        products: @products,
        categories: @categories
      })}
    <% end %>
    """
  end
end
