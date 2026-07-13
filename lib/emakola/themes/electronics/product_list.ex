defmodule Emakola.Themes.Electronics.ProductList do
  @moduledoc """
  Electronics theme product listing — cream bg, teal headers, sky-blue CTAs.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Electronics.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :search_query, :string, default: nil
  attr :active_category_slug, :string, default: nil

  def render(assigns) do
    ~H"""
    <div class="electronics-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.electronics_nav store={@store} cart_count={@cart_count} />

      <%!-- Page header --%>
      <section class="bg-[#134E4A] text-white">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p class="text-[11px] font-bold uppercase tracking-[0.18em] text-[#0EA5E9] mb-3">
            Shop electronics
          </p>
          <h1 class="electronics-heading text-4xl sm:text-5xl font-extrabold mb-3">
            {page_title(@search_query, @active_category_slug, @categories)}
          </h1>
          <p :if={@store.description not in [nil, ""]} class="text-sm text-white/75 max-w-xl">
            {@store.description}
          </p>
        </div>
      </section>

      <%!-- Category pills --%>
      <section :if={@categories != []} class="bg-[#F5EFE5] border-b border-[#E5E7EB]">
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
      <section class="bg-[#F5EFE5] py-10 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-sm text-[#4B5563] mb-6">
            <span class="font-semibold text-[#134E4A]">{length(@products)}</span>
            {if length(@products) == 1, do: "product", else: "products"}
          </p>

          <div :if={@products == []} class="text-center py-20">
            <span class="material-symbols-outlined text-[#134E4A]/30" style="font-size: 80px;">
              devices
            </span>
            <h2 class="electronics-heading text-2xl font-bold text-[#134E4A] mt-4 mb-2">
              No products found
            </h2>
            <p class="text-sm text-[#4B5563]">Try a different category.</p>
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center mt-6 px-6 py-3 rounded-full bg-[var(--theme-primary,#134E4A)] text-white text-sm font-bold hover:bg-[#0E3F3B] transition-colors"
            >
              Browse all
            </a>
          </div>

          <div
            :if={@products != []}
            class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-5"
          >
            <Shared.product_card
              :for={product <- @products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <Shared.electronics_footer store={@store} />
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

  defp page_title(_, _, _), do: "All Electronics"

  defp pill_class(true) do
    "inline-flex items-center px-4 py-2 rounded-full bg-[var(--theme-primary,#134E4A)] text-white text-sm font-bold transition-colors min-h-[40px]"
  end

  defp pill_class(false) do
    "inline-flex items-center px-4 py-2 rounded-full bg-white border border-[#E5E7EB] text-[#1F2937] text-sm font-medium hover:border-[#0EA5E9] hover:text-[#134E4A] transition-colors min-h-[40px]"
  end
end
