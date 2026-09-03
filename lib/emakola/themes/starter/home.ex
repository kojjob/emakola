defmodule Emakola.Themes.Starter.Home do
  @moduledoc """
  Starter theme home page -- clean, modern, minimal.

  Sections (gated by `@theme.sections.*` booleans):
  - Hero with indigo-to-slate gradient, large headline, CTA
  - Categories as horizontal scrollable pill chips
  - Featured products in a 2-col (mobile) / 4-col (desktop) grid
  - Trust section with three value propositions
  - Newsletter with simple email input in a light card
  - Footer via shared
  """
  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer
  alias Emakola.Themes.Starter.Shared

  @doc """
  Renders the Starter theme home page.

  Expects assigns:
  - `@store` -- store map with `.name`, `.slug`, `.description`, `.whatsapp_number`
  - `@products` -- list of products with `.title`, `.slug`, `.min_price`, `.max_price`, `.images`
  - `@categories` -- list of categories with `.name`, `.slug`
  - `@theme` -- theme config map with `.sections` booleans
  - `@cart_count` -- integer cart item count
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Starter)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="min-h-screen bg-white">
      <Shared.theme_styles theme={@theme} />
      <Shared.starter_nav store={@store} cart_count={@cart_count} />
      {SectionRenderer.home(assigns)}
      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end
end
