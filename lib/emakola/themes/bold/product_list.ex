defmodule Emakola.Themes.Bold.ProductList do
  @moduledoc """
  Bold theme product listing / shop page.

  Features:
  - Large bold page title with product count in muted text
  - Category links as underlined text (horizontal, editorial)
  - Minimal borderless search bar with bottom border only
  - Product grid: 2-col mobile, 3-col desktop, large images, editorial typography
  - Outlined load more button
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Bold.Shared

  @doc """
  Renders the Bold theme product list page.

  Expects assigns:
  - `@store` — store map
  - `@streams.products` — streamed product entries
  - `@products_count` — number of displayed products
  - `@categories` — list of categories
  - `@selected_category` — currently selected category ID or nil
  - `@search_query` — current search string
  - `@has_more` — boolean for load more button
  - `@theme` — theme config map
  - `@cart_count` — integer cart item count
  """
  attr :store, :map, required: true
  attr :streams, :map, required: true
  attr :products_count, :integer, required: true
  attr :categories, :list, required: true
  attr :selected_category, :any, default: nil
  attr :search_query, :string, default: ""
  attr :has_more, :boolean, default: false
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#F8FAFC]">
      <Shared.bold_nav store={@store} cart_count={@cart_count} />

      <%!-- Page Header --%>
      <div class="bg-[#F8FAFC] border-b border-[#E2E8F0]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14">
          <a
            href={store_path(@store.slug, "/")}
            class="text-sm text-[#64748B] hover:text-[#0F172A] transition-colors mb-4 inline-block"
            style="font-family: 'Inter', sans-serif;"
          >
            &larr; Back to Home
          </a>
          <h1
            class="text-3xl sm:text-4xl lg:text-5xl font-black text-[#0F172A] tracking-tight"
            style="font-family: 'Outfit', sans-serif;"
          >
            Shop
          </h1>
          <p
            class="text-sm text-[#94A3B8] mt-2"
            style="font-family: 'Inter', sans-serif;"
          >
            {@products_count} products
          </p>
        </div>
      </div>

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Category Links (Editorial Underlined) --%>
        <div
          :if={@categories != []}
          class="flex items-center gap-5 sm:gap-6 overflow-x-auto pb-6 mb-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
        >
          <%!-- `clear_filters` is handled by the platform's store directory, never
               by ProductListLive — this button raised FunctionClauseError. The
               "show everything" control is `filter_category` with "all", which is
               what the other ten themes send. --%>
          <button
            phx-click="filter_category"
            phx-value-category_id="all"
            class={[
              "flex-shrink-0 text-sm font-medium tracking-wide uppercase border-b-2 pb-1 transition-colors",
              if(is_nil(@selected_category) and (@search_query == "" or is_nil(@search_query)),
                do: "text-[#0F172A] border-[#F59E0B]",
                else: "text-[#64748B] border-transparent hover:text-[#0F172A] hover:border-[#0F172A]"
              )
            ]}
            style="font-family: 'Inter', sans-serif;"
          >
            All
          </button>
          <button
            :for={cat <- @categories}
            phx-click="filter_category"
            phx-value-category_id={cat.id}
            class={[
              "flex-shrink-0 text-sm font-medium tracking-wide uppercase border-b-2 pb-1 transition-colors",
              if(@selected_category == cat.id,
                do: "text-[#0F172A] border-[#F59E0B]",
                else: "text-[#64748B] border-transparent hover:text-[#0F172A] hover:border-[#0F172A]"
              )
            ]}
            style="font-family: 'Inter', sans-serif;"
          >
            {cat.name}
          </button>
        </div>

        <%!-- Search Bar (Minimal, Bottom Border Only) --%>
        <form phx-change="search" class="mb-8">
          <div class="relative max-w-lg">
            <svg
              class="absolute left-0 top-1/2 -translate-y-1/2 w-5 h-5 text-[#94A3B8]"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
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
              placeholder="Search..."
              phx-debounce="300"
              class="w-full pl-8 pr-4 py-3 border-0 border-b border-[#E2E8F0] bg-transparent text-sm text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none focus:border-[#0F172A] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            />
          </div>
        </form>

        <%!-- Product Grid --%>
        <div
          id="product-list"
          phx-update="stream"
          class="grid grid-cols-2 gap-6 sm:gap-8 lg:grid-cols-3 lg:gap-10"
        >
          <div id="product-list-empty" class="col-span-full hidden py-24 text-center only:block">
            <svg
              class="w-16 h-16 text-[#CBD5E1] mx-auto mb-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1"
                d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
              />
            </svg>
            <p
              class="text-[#0F172A] font-bold text-xl mb-2"
              style="font-family: 'Outfit', sans-serif;"
            >
              No products found
            </p>
            <p
              class="text-[#94A3B8] text-sm mb-6"
              style="font-family: 'Inter', sans-serif;"
            >
              Try adjusting your search or filters.
            </p>
            <button
              :if={@search_query != "" || @selected_category}
              phx-click="filter_category"
              phx-value-category_id="all"
              class="text-sm font-medium text-[#0F172A] border-b border-[#0F172A] hover:text-[#F59E0B] hover:border-[#F59E0B] transition-colors pb-0.5"
              style="font-family: 'Inter', sans-serif;"
            >
              Clear all filters
            </button>
          </div>
          <div
            :for={{dom_id, %{product: product}} <- @streams.products}
            id={dom_id}
            class="contents"
          >
            <Shared.product_card product={product} store={@store} />
          </div>
        </div>

        <div :if={@has_more} class="mt-14 text-center">
          <button
            phx-click="load_more"
            class="inline-flex items-center gap-2 px-10 py-3.5 border-2 border-[#0F172A] text-[#0F172A] text-sm font-bold tracking-wide uppercase hover:bg-[#0F172A] hover:text-white active:scale-[0.97] transition-all"
            style="font-family: 'Inter', sans-serif;"
          >
            Load More
          </button>
        </div>
      </div>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end
end
