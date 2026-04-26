defmodule Emakola.Themes.Pharmacy.ProductList do
  @moduledoc """
  Pharmacy theme product listing — clean grid with category pills and sort.
  """

  use Phoenix.Component

  alias Emakola.Themes.Pharmacy.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :search_query, :string, default: nil
  attr :active_category_slug, :string, default: nil

  def render(assigns) do
    ~H"""
    <div class="pharmacy-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.pharmacy_nav store={@store} cart_count={@cart_count} />

      <%!-- Page header --%>
      <section class="bg-[#14543E]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16 text-center">
          <p class="text-xs font-semibold uppercase tracking-wider text-[#A7E5C5] mb-3">
            Shop the pharmacy
          </p>
          <h1 class="pharmacy-heading text-4xl sm:text-5xl font-medium text-white mb-3">
            {page_title(@search_query, @active_category_slug, @categories)}
          </h1>
          <p class="text-sm text-[#F9F6F0]/80 max-w-xl mx-auto">
            Verified medicines, wellness products, and supplements — all from trusted brands.
          </p>
        </div>
      </section>

      <%!-- Category pills --%>
      <section :if={@categories != []} class="bg-[#F9F6F0] border-b border-[#E5E7EB]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-5">
          <div class="flex flex-wrap items-center gap-2 sm:gap-3">
            <a
              href={"/s/#{@store.slug}/products"}
              class={category_pill_class(@active_category_slug == nil)}
            >
              All
            </a>
            <a
              :for={category <- @categories}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class={category_pill_class(@active_category_slug == category.slug)}
            >
              {category.name}
            </a>
          </div>
        </div>
      </section>

      <%!-- Product grid --%>
      <section class="bg-[#F9F6F0] py-10 sm:py-14">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between mb-6">
            <p class="text-sm text-[#4B5563]">
              <span class="font-semibold text-[#14543E]">{length(@products)}</span>
              {if length(@products) == 1, do: "product", else: "products"}
            </p>
          </div>

          <div :if={@products == []} class="text-center py-20">
            <span class="material-symbols-outlined text-[#A7E5C5]" style="font-size: 80px;">
              inventory_2
            </span>
            <h2 class="pharmacy-heading text-2xl font-medium text-[#14543E] mt-4 mb-2">
              No products found
            </h2>
            <p class="text-sm text-[#4B5563]">
              Try a different category or search term.
            </p>
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center mt-6 px-6 py-3 rounded-full bg-[#14543E] text-white text-sm font-semibold hover:bg-[#0F3F2E] transition-colors"
            >
              Browse all products
            </a>
          </div>

          <div
            :if={@products != []}
            class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-5"
          >
            <Shared.product_card
              :for={product <- @products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <Shared.pharmacy_footer store={@store} />
    </div>
    """
  end

  # ── Helpers ──

  defp page_title(query, _category_slug, _categories) when is_binary(query) and query != "" do
    "Search: \"#{query}\""
  end

  defp page_title(_query, category_slug, categories) when is_binary(category_slug) do
    case Enum.find(categories, &(&1.slug == category_slug)) do
      %{name: name} -> name
      _ -> "Products"
    end
  end

  defp page_title(_, _, _), do: "All Products"

  defp category_pill_class(true) do
    "inline-flex items-center px-4 py-2 rounded-full bg-[#14543E] text-white text-sm font-semibold transition-colors"
  end

  defp category_pill_class(false) do
    "inline-flex items-center px-4 py-2 rounded-full bg-white border border-[#E5E7EB] text-[#1F2937] text-sm font-medium hover:bg-[#A7E5C5]/30 hover:border-[#A7E5C5] transition-colors"
  end
end
