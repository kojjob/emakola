defmodule Emakola.Themes.Fresh.ProductList do
  @moduledoc """
  Fresh theme product listing / shop page.

  Features:
  - Header with leaf icon and product count
  - Rounded search bar with cream background and green focus ring
  - Category circles (horizontal scroll)
  - Product grid with warm rounded cards (2-col mobile, 3-col tablet, 4-col desktop)
  - Load more pagination (green, rounded-full)
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fresh.Shared

  @doc """
  Renders the Fresh theme product list page.

  Expects assigns:
  - `@store` — store map
  - `@products` — list of products
  - `@categories` — list of categories
  - `@selected_category` — currently selected category ID or nil
  - `@search_query` — current search string
  - `@has_more` — boolean for load more button
  - `@theme` — theme config map
  - `@cart_count` — number of items in cart
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :selected_category, :any, default: nil
  attr :search_query, :string, default: ""
  attr :has_more, :boolean, default: false
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FEFCE8]">
      <Shared.fresh_nav store={@store} cart_count={@cart_count} />
      <%!-- Header --%>
      <div class="bg-gradient-to-r from-[#059669] to-[#047857]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
          <%!-- Breadcrumb --%>
          <nav aria-label="Breadcrumb" class="mb-4">
            <ol class="flex items-center gap-2 text-xs text-white/60">
              <li>
                <a href={store_path(@store.slug, "/")} class="hover:text-white transition-colors">
                  Home
                </a>
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
              <li class="text-white font-medium">Products</li>
            </ol>
          </nav>

          <div class="flex items-center gap-2.5">
            <span
              class="material-symbols-outlined text-white/80"
              style="font-size: 28px;"
            >
              eco
            </span>
            <div>
              <h1
                class="text-3xl sm:text-4xl font-bold text-white"
                style="font-family: 'Nunito', sans-serif;"
              >
                Fresh Products
              </h1>
              <p class="text-white/70 text-sm mt-1" style="font-family: 'Inter', sans-serif;">
                {length(@products)} products
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <%!-- Search Bar --%>
        <form phx-change="search" class="mb-6">
          <div class="relative max-w-lg">
            <svg
              class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-[#059669]"
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
              placeholder="Search fresh products..."
              phx-debounce="300"
              class="w-full pl-12 pr-4 py-3 border border-[#D9F99D] rounded-full text-sm text-cta-dark bg-[#FEFCE8] placeholder:text-[#92400E]/40 focus:outline-none focus:ring-2 focus:ring-[#059669] focus:border-transparent shadow-sm"
              style="font-family: 'Inter', sans-serif;"
            />
          </div>
        </form>

        <%!-- Category Circles (Horizontal Scroll) --%>
        <div
          :if={@categories != []}
          class="flex gap-5 overflow-x-auto pb-6 mb-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
          role="list"
        >
          <button
            phx-click="filter_category"
            phx-value-id="all"
            class={[
              "flex flex-col items-center gap-2 flex-shrink-0 group cursor-pointer"
            ]}
          >
            <div class={[
              "w-[76px] h-[76px] rounded-full p-[3px] group-hover:scale-110 transition-transform duration-200",
              if(is_nil(@selected_category),
                do: "bg-gradient-to-br from-[#059669] to-[#047857] shadow-lg shadow-emerald-200",
                else: "bg-gradient-to-br from-[#D9F99D] to-[#A3E635] shadow-sm"
              )
            ]}>
              <div class="w-full h-full rounded-full bg-[#FEFCE8] border-[3px] border-[#FEFCE8] flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-[#059669]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
                  />
                </svg>
              </div>
            </div>
            <span class={[
              "text-xs font-semibold text-center whitespace-nowrap",
              if(is_nil(@selected_category),
                do: "text-[#059669]",
                else: "text-[#78350F] group-hover:text-[#059669]"
              )
            ]}>
              All
            </span>
          </button>
          <Shared.category_circle
            :for={cat <- @categories}
            category={cat}
            store_slug={@store.slug}
            active={@selected_category == cat.id}
          />
        </div>

        <%!-- Product Grid --%>
        <%= if @products == [] do %>
          <div class="py-20 text-center">
            <div class="w-20 h-20 rounded-full bg-[#ECFDF5] mx-auto mb-4 flex items-center justify-center">
              <span
                class="material-symbols-outlined text-[#059669]"
                style="font-size: 36px;"
              >
                eco
              </span>
            </div>
            <p
              class="text-[#78350F] font-bold text-lg mb-2"
              style="font-family: 'Nunito', sans-serif;"
            >
              No products found
            </p>
            <p class="text-[#92400E]/70 text-sm mb-4" style="font-family: 'Inter', sans-serif;">
              Try a different search or category
            </p>
            <button
              :if={@search_query != "" || @selected_category}
              phx-click="filter_category"
              phx-value-id="all"
              class="text-sm font-bold text-[#059669] hover:text-[#047857] transition-colors"
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
              class="inline-flex items-center gap-2 px-10 py-3.5 bg-[var(--theme-primary,#047857)] text-white rounded-full text-sm font-bold hover:opacity-90 active:scale-[0.97] transition-all shadow-lg shadow-emerald-200"
              style="font-family: 'Inter', sans-serif;"
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

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end
end
