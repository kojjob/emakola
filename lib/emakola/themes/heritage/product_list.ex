defmodule Emakola.Themes.Heritage.ProductList do
  @moduledoc """
  Heritage theme product listing — burgundy hero header + cream grid
  with serif titles and gold pill chips.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Heritage.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :search_query, :string, default: nil
  attr :active_category_slug, :string, default: nil

  def render(assigns) do
    ~H"""
    <div class="heritage-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.heritage_nav store={@store} cart_count={@cart_count} />

      <%!-- Burgundy page header --%>
      <section class="bg-[#7A1F1F] text-[#F5EFE0]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 text-center">
          <p class="text-xs font-bold uppercase tracking-[0.3em] text-[#D4A843] mb-3">
            Our Collection
          </p>
          <h1 class="heritage-heading text-4xl sm:text-5xl lg:text-6xl font-bold">
            {page_title(@search_query, @active_category_slug, @categories)}
          </h1>
          <p class="text-base text-[#F5EFE0]/80 max-w-xl mx-auto mt-4">
            Heritage crafts, hand-made by Africa's finest artisans.
          </p>
        </div>
      </section>

      <%!-- Category pills --%>
      <section :if={@categories != []} class="bg-[#FAF6EC] border-b border-[#E8DBC2]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex flex-wrap items-center justify-center gap-2 sm:gap-3">
            <a
              href={store_path(@store.slug, "/products")}
              class={pill_class(@active_category_slug == nil)}
            >
              All Crafts
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
      <section class="bg-[#FAF6EC] py-12 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-sm text-[#6B4423]/70 mb-8 text-center">
            <span class="font-bold text-[#7A1F1F]">{length(@products)}</span>
            {if length(@products) == 1, do: "piece", else: "pieces"} curated by hand
          </p>

          <div :if={@products == []} class="text-center py-20">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              class="w-20 h-20 text-[#D4A843]/40 mx-auto"
              fill="currentColor"
              aria-hidden="true"
            >
              <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
            </svg>
            <h2 class="heritage-heading text-3xl font-semibold text-[#7A1F1F] mt-4 mb-2">
              No pieces here yet
            </h2>
            <p class="text-sm text-[#6B4423]/70">Try a different collection.</p>
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center mt-6 px-6 py-3 rounded-full bg-[#7A1F1F] text-[#F5EFE0] text-sm font-bold hover:bg-[#5A1717] transition-colors"
            >
              Browse all
            </a>
          </div>

          <div
            :if={@products != []}
            class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-6"
          >
            <Shared.product_card
              :for={product <- @products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <Shared.heritage_footer store={@store} />
    </div>
    """
  end

  defp page_title(query, _, _) when is_binary(query) and query != "" do
    "Search: \"#{query}\""
  end

  defp page_title(_, category_slug, categories) when is_binary(category_slug) do
    case Enum.find(categories, &(&1.slug == category_slug)) do
      %{name: name} -> name
      _ -> "The Heritage Collection"
    end
  end

  defp page_title(_, _, _), do: "The Heritage Collection"

  defp pill_class(true) do
    "inline-flex items-center px-5 py-2.5 rounded-full bg-[#7A1F1F] text-[#F5EFE0] text-sm font-bold transition-colors min-h-[44px]"
  end

  defp pill_class(false) do
    "inline-flex items-center px-5 py-2.5 rounded-full bg-white border border-[#E8DBC2] text-[#3D2817] text-sm font-medium hover:border-[#D4A843] hover:text-[#7A1F1F] transition-colors min-h-[44px]"
  end
end
