defmodule Emakola.Themes.Fresh.Home do
  @moduledoc """
  Fresh theme home page — warm, organic, appetizing.

  Renders theme chrome only — the CSS variable block, the Fresh nav and the
  footer. Everything between them is the store's effective home-section
  layout, rendered by `SectionRenderer`; the section markup lives in
  `Emakola.Themes.Fresh.Sections.*`, each a top-level sibling owning its own
  max-width container and horizontal padding.
  """
  use Phoenix.Component

  alias Emakola.Themes.Fresh.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  @doc """
  Renders the Fresh theme home page.

  Expects assigns:
  - `@store` — store map with `.name`, `.slug`, `.description`, `.whatsapp_number`
  - `@products` — list of products
  - `@categories` — list of categories
  - `@theme` — theme config map with `.sections` booleans
  - `@cart_count` — number of items in cart
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Fresh)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="min-h-screen bg-[#FEFCE8]">
      <Shared.theme_styles theme={@theme} />
      <Shared.fresh_nav store={@store} cart_count={@cart_count} />
      {SectionRenderer.home(assigns)}
      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end
end
