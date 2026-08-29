defmodule Emakola.Themes.Beauty.ProductList do
  @moduledoc """
  Beauty theme product listing — warm cream grid with serif headers
  and gold accents.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Beauty.Shared

  attr :store, :map, required: true
  attr :streams, :map, required: true
  attr :products_count, :integer, required: true
  attr :categories, :list, default: []
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :has_more, :boolean, default: false
  attr :search_query, :string, default: nil
  attr :active_category_slug, :string, default: nil

  def render(assigns) do
    ~H"""
    <div class="beauty-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.beauty_nav store={@store} cart_count={@cart_count} />

      <%!-- Page header --%>
      <section class="bg-[#6B4423] text-[#FAF6EE]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 text-center">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#C9925E] mb-3">
            Our Collection
          </p>
          <h1 class="beauty-heading text-5xl sm:text-6xl font-semibold mb-4">
            {page_title(@search_query, @active_category_slug, @categories)}
          </h1>
          <p class="text-base text-[#FAF6EE]/75 max-w-xl mx-auto">
            Botanical formulas crafted for the rituals you love.
          </p>
        </div>
      </section>

      <%!-- Category pills --%>
      <section :if={@categories != []} class="bg-[#F5EFE5] border-b border-[#E8DBC8]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex flex-wrap items-center justify-center gap-2 sm:gap-3">
            <a
              href={store_path(@store.slug, "/products")}
              class={pill_class(@active_category_slug == nil)}
            >
              All
            </a>
            <a
              :for={category <- @categories}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class={pill_class(@active_category_slug == category.slug)}
            >
              {category.name}
            </a>
          </div>
        </div>
      </section>

      <%!-- Product grid --%>
      <section class="bg-[#F5EFE5] py-12 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-sm text-[#6B4423]/70 mb-8 text-center">
            <span class="font-semibold text-[#6B4423]">{@products_count}</span>
            {if @products_count == 1, do: "product", else: "products"} curated for you
          </p>

          <div
            id="product-list"
            phx-update="stream"
            class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-6"
          >
            <div id="product-list-empty" class="col-span-full hidden text-center py-20 only:block">
              <span class="material-symbols-outlined text-[#C9925E]/40" style="font-size: 80px;">
                spa
              </span>
              <h2 class="beauty-heading text-3xl font-semibold text-[#3D2F25] mt-4 mb-2">
                No products found
              </h2>
              <p class="text-sm text-[#6B4423]/70">Try a different category.</p>
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center mt-6 px-6 py-3 rounded-full bg-[#6B4423] text-[#FAF6EE] text-sm font-semibold hover:bg-[#5A381D] transition-colors"
              >
                Browse all
              </a>
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
              class="inline-flex min-h-12 items-center rounded-full bg-[#6B4423] px-8 text-sm font-semibold text-[#FAF6EE] transition-colors hover:bg-[#5A381D] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#C9925E] focus-visible:ring-offset-2"
            >
              Load more
            </button>
          </div>
        </div>
      </section>

      <Shared.beauty_footer store={@store} />
    </div>
    """
  end

  defp page_title(query, _, _) when is_binary(query) and query != "" do
    "Search: \"#{query}\""
  end

  defp page_title(_, category_slug, categories) when is_binary(category_slug) do
    case Enum.find(categories, &(&1.slug == category_slug)) do
      %{name: name} -> name
      _ -> "Shop the Collection"
    end
  end

  defp page_title(_, _, _), do: "Shop the Collection"

  defp pill_class(true) do
    "inline-flex items-center px-5 py-2.5 rounded-full bg-[#6B4423] text-[#FAF6EE] text-sm font-semibold transition-colors min-h-[44px]"
  end

  defp pill_class(false) do
    "inline-flex items-center px-5 py-2.5 rounded-full bg-white border border-[#E8DBC8] text-[#3D2F25] text-sm font-medium hover:border-[#C9925E] hover:text-[#6B4423] transition-colors min-h-[44px]"
  end
end
