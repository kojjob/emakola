defmodule Emakola.Themes.Spotlight.ProductList do
  @moduledoc "Spotlight product list — branded responsive grid."

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :has_more, :boolean, default: false
  attr :streams, :map, required: true
  attr :products_count, :integer, required: true
  attr :categories, :list, default: []

  def render(assigns) do
    ~H"""
    <div class="spot-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.nav store={@store} cart_count={@cart_count} />

      <section class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="flex items-baseline justify-between mb-8">
          <h1 class="spot-display text-4xl uppercase">Shop</h1>
          <span class="text-sm text-[#7A7468]">{Emakola.Plural.count(@products_count, "item")}</span>
        </div>
        <div
          id="product-list"
          phx-update="stream"
          class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-5 sm:gap-6"
        >
          <div
            id="product-list-empty"
            class="col-span-full hidden text-center py-24 text-[#7A7468] only:block"
          >
            <p class="text-sm">No products yet. Check back soon.</p>
          </div>
          <div
            :for={{dom_id, %{product: product}} <- @streams.products}
            id={dom_id}
            class="contents"
          >
            <Shared.product_card product={product} store={@store} />
          </div>
        </div>
        <div :if={@has_more} class="mt-12 text-center">
          <button
            type="button"
            phx-click="load_more"
            class="inline-flex min-h-12 items-center rounded-full bg-[#16130F] px-8 text-sm font-semibold text-white transition-colors hover:bg-[#7C3AED] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7C3AED] focus-visible:ring-offset-2"
          >
            Load more
          </button>
        </div>
      </section>

      <Shared.footer store={@store} />
    </div>
    """
  end
end
