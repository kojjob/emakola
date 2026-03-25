defmodule Emakola.Themes.Vibrant.ProductList do
  @moduledoc """
  Vibrant theme product listing / shop page.

  Features:
  - Warm-toned header with breadcrumb
  - Horizontal pill category filters
  - Search bar with warm accents
  - Product grid with bold rounded cards (2-col mobile, 3-col tablet, 4-col desktop)
  - Load more pagination
  """
  use Phoenix.Component

  alias Emakola.Themes.Vibrant.Shared

  @doc """
  Renders the Vibrant theme product list page.

  Expects assigns:
  - `@store` — store map
  - `@products` — list of products
  - `@categories` — list of categories
  - `@selected_category` — currently selected category ID or nil
  - `@search_query` — current search string
  - `@has_more` — boolean for load more button
  - `@theme` — theme config map
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :selected_category, :any, default: nil
  attr :search_query, :string, default: ""
  attr :has_more, :boolean, default: false
  attr :theme, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FFFBEB]">
      <%!-- Warm-Toned Header --%>
      <div class="bg-gradient-to-r from-[var(--theme-primary,#DC2626)] to-[var(--theme-accent,#7C2D12)]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
          <%!-- Breadcrumb --%>
          <nav aria-label="Breadcrumb" class="mb-4">
            <ol class="flex items-center gap-2 text-xs text-white/60">
              <li>
                <a href={"/s/#{@store.slug}"} class="hover:text-white transition-colors">Home</a>
              </li>
              <li>
                <svg
                  class="w-3 h-3 inline"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="m9 5 7 7-7 7" />
                </svg>
              </li>
              <li class="text-white font-medium">Shop</li>
            </ol>
          </nav>

          <h1
            class="text-3xl sm:text-4xl font-bold text-white"
            style="font-family: 'Playfair Display', serif;"
          >
            Shop All
          </h1>
          <p class="text-white/70 text-sm mt-1" style="font-family: 'DM Sans', sans-serif;">
            {length(@products)} products
          </p>
        </div>
      </div>

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <%!-- Category Filter Pills (Horizontal Scroll) --%>
        <div
          :if={@categories != []}
          class="flex gap-2 overflow-x-auto pb-4 mb-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
        >
          <button
            phx-click="filter_category"
            phx-value-category_id="all"
            class={[
              "flex-shrink-0 px-5 py-2.5 rounded-full text-sm font-semibold transition-all",
              if(is_nil(@selected_category),
                do: "bg-[var(--theme-primary,#DC2626)] text-white shadow-md shadow-red-200",
                else:
                  "bg-white text-[#78350F] border border-[#FDE68A] hover:border-[var(--theme-primary,#DC2626)] hover:text-[var(--theme-primary,#DC2626)]"
              )
            ]}
            style="font-family: 'DM Sans', sans-serif;"
          >
            All
          </button>
          <button
            :for={cat <- @categories}
            phx-click="filter_category"
            phx-value-category_id={cat.id}
            class={[
              "flex-shrink-0 px-5 py-2.5 rounded-full text-sm font-semibold transition-all",
              if(@selected_category == cat.id,
                do: "bg-[var(--theme-primary,#DC2626)] text-white shadow-md shadow-red-200",
                else:
                  "bg-white text-[#78350F] border border-[#FDE68A] hover:border-[var(--theme-primary,#DC2626)] hover:text-[var(--theme-primary,#DC2626)]"
              )
            ]}
            style="font-family: 'DM Sans', sans-serif;"
          >
            {cat.name}
          </button>
        </div>

        <%!-- Search Bar --%>
        <form phx-change="search" class="mb-6">
          <div class="relative max-w-lg">
            <svg
              class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-[#D97706]"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
              />
            </svg>
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search products..."
              phx-debounce="300"
              class="w-full pl-12 pr-4 py-3 border border-[#FDE68A] rounded-full text-sm text-[#1C1917] bg-white placeholder:text-[#D97706]/50 focus:outline-none focus:ring-2 focus:ring-[var(--theme-primary,#DC2626)] focus:border-transparent shadow-sm"
              style="font-family: 'DM Sans', sans-serif;"
            />
          </div>
        </form>

        <%!-- Product Grid --%>
        <%= if @products == [] do %>
          <div class="py-20 text-center">
            <div class="w-20 h-20 rounded-full bg-[#FEF3C7] mx-auto mb-4 flex items-center justify-center">
              <svg
                class="w-10 h-10 text-[#D97706]"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                />
              </svg>
            </div>
            <p
              class="text-[#78350F] font-medium text-lg mb-2"
              style="font-family: 'Playfair Display', serif;"
            >
              No products found
            </p>
            <p class="text-[#92400E]/70 text-sm mb-4" style="font-family: 'DM Sans', sans-serif;">
              Try a different search or category
            </p>
            <button
              :if={@search_query != "" || @selected_category}
              phx-click="filter_category"
              phx-value-category_id="all"
              class="text-sm font-bold text-[var(--theme-primary,#DC2626)] hover:text-[#B91C1C] transition-colors"
            >
              Clear filters
            </button>
          </div>
        <% else %>
          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-5 lg:gap-6">
            <Shared.product_card :for={product <- @products} product={product} store={@store} />
          </div>

          <div :if={@has_more} class="mt-10 text-center">
            <button
              phx-click="load_more"
              class="inline-flex items-center gap-2 px-10 py-3.5 bg-[var(--theme-primary,#DC2626)] text-white rounded-full text-sm font-bold hover:bg-[#B91C1C] active:scale-[0.97] transition-all shadow-lg shadow-red-200"
              style="font-family: 'DM Sans', sans-serif;"
            >
              Load More
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19.5 13.5 12 21m0 0-7.5-7.5M12 21V3"
                />
              </svg>
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
