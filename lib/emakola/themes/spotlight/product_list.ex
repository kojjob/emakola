defmodule Emakola.Themes.Spotlight.ProductList do
  @moduledoc "Spotlight product list — branded responsive grid."

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    ~H"""
    <div class="spot-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.nav store={@store} cart_count={@cart_count} />

      <section class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="flex items-baseline justify-between mb-8">
          <h1 class="spot-display text-4xl uppercase">Shop</h1>
          <span class="text-sm text-[#9b968c]">{length(@products)} items</span>
        </div>
        <div
          :if={@products != []}
          class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-5 sm:gap-6"
        >
          <Shared.product_card :for={product <- @products} product={product} store={@store} />
        </div>
        <div :if={@products == []} class="text-center py-24 text-[#9b968c]">
          <p class="text-sm">No products yet. Check back soon.</p>
        </div>
      </section>

      <Shared.footer store={@store} />
    </div>
    """
  end
end
