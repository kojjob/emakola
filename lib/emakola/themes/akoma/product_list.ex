defmodule Emakola.Themes.Akoma.ProductList do
  @moduledoc "Akoma product list — clean responsive grid."

  use Phoenix.Component

  alias Emakola.Themes.Akoma.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    ~H"""
    <div class="akoma-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.akoma_nav store={@store} cart_count={@cart_count} />

      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10">
        <div class="flex items-baseline justify-between mb-8">
          <h1 class="akoma-heading text-2xl font-bold text-[#1A1A1A]">All products</h1>
          <span class="text-sm text-[#9CA3AF]">{length(@products)} items</span>
        </div>

        <div
          :if={@products != []}
          class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6"
        >
          <Shared.product_card :for={product <- @products} product={product} store={@store} />
        </div>

        <div :if={@products == []} class="text-center py-24 text-[#9CA3AF]">
          <p class="text-sm">No products yet. Check back soon.</p>
        </div>
      </section>

      <Shared.akoma_footer store={@store} />
    </div>
    """
  end
end
