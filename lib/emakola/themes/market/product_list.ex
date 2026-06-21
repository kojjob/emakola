defmodule Emakola.Themes.Market.ProductList do
  @moduledoc """
  Market theme — product list page renderer.

  Renders the product listing with breadcrumbs, search, category filters
  (desktop sidebar + mobile dropdown), product grid, and load-more pagination.
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [product_card: 1, bottom_nav: 1]

  def render(assigns) do
    ~H"""
    <%!-- Hero Header Section --%>
    <div class="bg-[#F8FAFC] border-b border-[#E2E8F0] mb-8 lg:mb-12">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- Breadcrumb --%>
        <nav aria-label="Breadcrumb" class="py-5">
          <ol class="flex items-center gap-2 text-xs text-[#64748B] font-medium tracking-wide">
            <li>
              <a href={"/@#{@store.slug}"} class="hover:text-[#0F172A] transition-colors">Home</a>
            </li>
            <li>
              <svg
                class="w-3.5 h-3.5 inline text-[#CBD5E1]"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="m9 5 7 7-7 7" />
              </svg>
            </li>
            <li class="text-[#0F172A]">Shop</li>
          </ol>
        </nav>

        <%!-- Page header --%>
        <div class="py-8 sm:py-12 flex flex-col items-center text-center lg:items-start lg:text-left">
          <h1 class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-[#0F172A] tracking-[-0.02em] mb-4">
            Shop All
          </h1>
          <p class="text-base sm:text-lg text-[#64748B] max-w-2xl leading-relaxed">
            Browse our full collection of premium products and accessories.
            <span class="inline-flex items-center justify-center px-2.5 py-0.5 ml-1.5 text-[0.6875rem] font-bold uppercase tracking-wider bg-white border border-[#E2E8F0] shadow-sm rounded-full text-[#475569] align-middle">
              {length(@products)} items
            </span>
          </p>
        </div>
      </div>
    </div>

    <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-0">
      <%!-- Main content: sidebar + products --%>
      <div class="flex gap-8 pb-16">
        <%!-- Filter sidebar (desktop) --%>
        <aside class="hidden lg:block w-[240px] flex-shrink-0">
          <div class="sticky top-28 space-y-8">
            <%!-- Category filter --%>
            <div>
              <h3 class="text-xs font-bold text-[#0F172A] uppercase tracking-widest mb-4 border-b border-[#E2E8F0] pb-3">
                Categories
              </h3>
              <div class="space-y-1">
                <button
                  phx-click="filter_category"
                  phx-value-category_id="all"
                  class={"w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-sm transition-all " <> (if is_nil(@selected_category), do: "bg-[#0F172A] text-white font-semibold shadow-sm", else: "text-[#64748B] hover:bg-[#F1F5F9] hover:text-[#0F172A]")}
                >
                  <span>All Products</span>
                  <span :if={is_nil(@selected_category)} class="w-1.5 h-1.5 rounded-full bg-white">
                  </span>
                </button>
                <button
                  :for={cat <- @categories}
                  phx-click="filter_category"
                  phx-value-category_id={cat.id}
                  class={"w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-sm transition-all " <> (if @selected_category == cat.id, do: "bg-[#0F172A] text-white font-semibold shadow-sm", else: "text-[#64748B] hover:bg-[#F1F5F9] hover:text-[#0F172A]")}
                >
                  <span>{cat.name}</span>
                  <span :if={@selected_category == cat.id} class="w-1.5 h-1.5 rounded-full bg-white">
                  </span>
                </button>
              </div>
            </div>
          </div>
        </aside>

        <%!-- Product grid area --%>
        <div class="flex-1 min-w-0">
          <%!-- Top Bar: Search & Mobile Categories --%>
          <div class="mb-8 space-y-4 lg:space-y-0 lg:flex lg:items-center lg:justify-end lg:mb-10">
            <%!-- Search --%>
            <form phx-change="search" class="w-full lg:max-w-xs xl:max-w-sm">
              <div class="relative group">
                <svg
                  class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4.5 h-4.5 text-[#94A3B8] group-focus-within:text-store-accent transition-colors"
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
                  class="w-full pl-10 pr-4 py-2.5 border border-[#E2E8F0] rounded-xl text-sm text-[#0F172A] bg-white hover:border-[#CBD5E1] placeholder:text-[#94A3B8] focus:outline-none focus:ring-2 focus:ring-[#B45309]/20 focus:border-[#B45309] transition-all shadow-sm"
                />
              </div>
            </form>

            <%!-- Mobile category pills (horizontal scroll) --%>
            <div class="lg:hidden flex items-center gap-2 overflow-x-auto pb-2 -mx-4 px-4 sm:mx-0 sm:px-0 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
              <button
                phx-click="filter_category"
                phx-value-category_id="all"
                class={"flex-shrink-0 px-4 py-2 rounded-full text-[0.8125rem] font-semibold transition-all border " <> (if is_nil(@selected_category), do: "bg-[#0F172A] text-white border-[#0F172A] shadow-md", else: "bg-white text-[#475569] border-[#E2E8F0] hover:border-[#CBD5E1] hover:bg-[#F8FAFC]")}
              >
                All
              </button>
              <button
                :for={cat <- @categories}
                phx-click="filter_category"
                phx-value-category_id={cat.id}
                class={"flex-shrink-0 px-4 py-2 rounded-full text-[0.8125rem] font-semibold transition-all border " <> (if @selected_category == cat.id, do: "bg-[#0F172A] text-white border-[#0F172A] shadow-md", else: "bg-white text-[#475569] border-[#E2E8F0] hover:border-[#CBD5E1] hover:bg-[#F8FAFC]")}
              >
                {cat.name}
              </button>
            </div>
          </div>

          <%!-- Products --%>
          <%= if @products == [] do %>
            <div class="py-24 text-center border-2 border-dashed border-[#E2E8F0] rounded-[24px] bg-[#F8FAFC]">
              <div class="w-16 h-16 mx-auto bg-white rounded-full flex items-center justify-center shadow-sm border border-[#F1F5F9] mb-4">
                <svg
                  class="w-8 h-8 text-[#94A3B8]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607zM10.5 7.5v6m3-3h-6"
                  />
                </svg>
              </div>
              <h3 class="text-xl font-bold text-[#0F172A] mb-1.5">No products found</h3>
              <p class="text-[#64748B] text-[0.9375rem] max-w-sm mx-auto mb-6">
                We couldn't find anything matching your search. Try exploring other categories.
              </p>
              <button
                :if={@search_query != "" || @selected_category}
                phx-click="filter_category"
                phx-value-category_id="all"
                class="inline-flex items-center gap-2 px-6 py-2.5 bg-white border border-[#E2E8F0] shadow-sm rounded-full text-sm font-semibold text-[#0F172A] hover:bg-[#F8FAFC] hover:border-[#CBD5E1] transition-all focus:outline-none focus:ring-2 focus:ring-[#0F172A] focus:ring-offset-2"
              >
                Clear all filters
              </button>
            </div>
          <% else %>
            <div class="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-6 lg:gap-8">
              <.product_card :for={product <- @products} product={product} store={@store} />
            </div>

            <div :if={@has_more} class="mt-10 text-center">
              <button
                phx-click="load_more"
                class="inline-flex items-center gap-2 px-8 py-3 border border-[#E2E8F0] rounded-lg text-sm font-semibold text-[#0F172A] bg-white hover:bg-[#F1F5F9] transition-colors"
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
    </div>

    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />

    <.bottom_nav store_slug={@store.slug} active_tab={:search} cart_count={@cart_count} />
    """
  end
end
