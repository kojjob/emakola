defmodule Emakola.Themes.HomeLiving.ProductList do
  @moduledoc """
  Home Living theme product listing — oat bg with editorial product
  cards.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.HomeLiving.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :search_query, :string, default: nil
  attr :active_category_slug, :string, default: nil

  def render(assigns) do
    ~H"""
    <div class="home-living-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.home_living_nav store={@store} cart_count={@cart_count} />

      <%!-- Page header --%>
      <section class="bg-[#FAF7F2] border-b border-[#E8DBC8]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#92400E] mb-3">
            Shop the collection
          </p>
          <h1 class="home-living-heading text-4xl sm:text-5xl font-medium text-[#3F2D1A] mb-3">
            {page_title(@search_query, @active_category_slug, @categories)}
          </h1>
          <%!-- Was "Crafted in small batches with quality materials." — how every
               product in every Home Living store was manufactured, printed above
               the grid whether or not any of it was true. --%>
          <p :if={@store.description} class="text-sm text-[#92400E]/80 max-w-xl">
            {@store.description}
          </p>
        </div>
      </section>

      <%!-- Category pills --%>
      <section :if={@categories != []} class="bg-[#FAF7F2] border-b border-[#E8DBC8]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-5">
          <div class="flex flex-wrap items-center gap-2 sm:gap-3">
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
      <section class="bg-[#FAF7F2] py-10 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-sm text-[#92400E]/70 mb-6">
            <span class="font-semibold text-[#3F2D1A]">{length(@products)}</span>
            {if length(@products) == 1, do: "piece", else: "pieces"}
          </p>

          <div :if={@products == []} class="text-center py-20">
            <span class="material-symbols-outlined text-[#C2410C]/40" style="font-size: 80px;">
              chair
            </span>
            <h2 class="home-living-heading text-2xl font-medium text-[#3F2D1A] mt-4 mb-2">
              No pieces found
            </h2>
            <p class="text-sm text-[#92400E]/70">Try a different category.</p>
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center mt-6 px-6 py-3 rounded-xl bg-[#C2410C] text-white text-sm font-semibold hover:bg-[#9A340A] transition-colors"
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

      <Shared.home_living_footer store={@store} />
    </div>
    """
  end

  defp page_title(query, _, _) when is_binary(query) and query != "" do
    "Search: \"#{query}\""
  end

  defp page_title(_, category_slug, categories) when is_binary(category_slug) do
    case Enum.find(categories, &(&1.slug == category_slug)) do
      %{name: name} -> name
      _ -> "Shop"
    end
  end

  defp page_title(_, _, _), do: "All pieces"

  defp pill_class(true) do
    "inline-flex items-center px-4 py-2 rounded-xl bg-[#C2410C] text-white text-sm font-semibold transition-colors min-h-[40px]"
  end

  defp pill_class(false) do
    "inline-flex items-center px-4 py-2 rounded-xl bg-white border border-[#E8DBC8] text-[#3F2D1A] text-sm font-medium hover:border-[#C2410C] hover:text-[#C2410C] transition-colors min-h-[40px]"
  end
end
