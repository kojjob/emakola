defmodule Emakola.Themes.Fashion.ProductList do
  @moduledoc """
  Fashion theme product listing — editorial layout with Playfair
  display heading and lookbook product cards.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fashion.Shared

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
    <div class="fashion-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.fashion_nav store={@store} cart_count={@cart_count} />

      <%!-- Editorial header --%>
      <section class="bg-[#FAF6EE] border-b border-[#E7E5E4]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-20 text-center">
          <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-4">
            The Edit
          </p>
          <h1 class="fashion-display text-5xl sm:text-6xl lg:text-7xl text-[#1C1917] leading-tight mb-3">
            {page_title(@search_query, @active_category_slug, @categories)}
          </h1>
          <p class="text-sm text-[#57534E] italic fashion-heading max-w-xl mx-auto">
            Made by tailors. Worn by you.
          </p>
        </div>
      </section>

      <%!-- Category pills --%>
      <section :if={@categories != []} class="bg-[#FAF6EE] border-b border-[#E7E5E4]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-5">
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
      <section class="bg-[#FAF6EE] py-12 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-xs text-[#57534E] uppercase tracking-[0.18em] mb-8 text-center">
            <span class="font-semibold text-[#1C1917]">{@products_count}</span>
            {if @products_count == 1, do: "piece", else: "pieces"}
          </p>

          <div
            id="product-list"
            phx-update="stream"
            class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-8"
          >
            <div id="product-list-empty" class="col-span-full hidden text-center py-20 only:block">
              <span class="material-symbols-outlined text-[#5B21B6]/30" style="font-size: 80px;">
                checkroom
              </span>
              <h2 class="fashion-display text-3xl text-[#1C1917] mt-4 mb-2">
                No pieces found
              </h2>
              <p class="text-sm text-[#57534E]">Try a different category.</p>
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center mt-6 px-6 py-3 rounded-full bg-[var(--theme-primary,#5B21B6)] text-white text-xs font-bold uppercase tracking-wider hover:bg-[#4C1D95] transition-colors"
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
              class="inline-flex min-h-12 items-center rounded-full bg-[var(--theme-primary,#5B21B6)] px-8 text-xs font-bold uppercase tracking-wider text-white transition-colors hover:bg-[#4C1D95] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5B21B6] focus-visible:ring-offset-2"
            >
              Load more
            </button>
          </div>
        </div>
      </section>

      <Shared.fashion_footer store={@store} />
    </div>
    """
  end

  defp page_title(query, _, _) when is_binary(query) and query != "" do
    "\"#{query}\""
  end

  defp page_title(_, category_slug, categories) when is_binary(category_slug) do
    case Enum.find(categories, &(&1.slug == category_slug)) do
      %{name: name} -> name
      _ -> "The Collection"
    end
  end

  defp page_title(_, _, _), do: "The Collection"

  defp pill_class(true) do
    "inline-flex items-center px-5 py-2 rounded-full bg-[#5B21B6] text-white text-[11px] font-bold uppercase tracking-[0.18em] transition-colors min-h-[40px]"
  end

  defp pill_class(false) do
    "inline-flex items-center px-5 py-2 rounded-full bg-white border border-[#E7E5E4] text-[#1C1917] text-[11px] font-medium uppercase tracking-[0.18em] hover:border-[#5B21B6] hover:text-[#5B21B6] transition-colors min-h-[40px]"
  end
end
