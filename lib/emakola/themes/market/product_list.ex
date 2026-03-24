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
    <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-0">
      <%!-- Breadcrumb --%>
      <nav aria-label="Breadcrumb" class="pt-6 pb-4">
        <ol class="flex items-center gap-2 text-xs text-[#475569]">
          <li>
            <a href={"/s/#{@store.slug}"} class="hover:text-[#0F172A] transition-colors">Home</a>
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
          <li class="text-[#0F172A] font-medium">Shop</li>
        </ol>
      </nav>

      <%!-- Page header --%>
      <div class="flex items-end justify-between gap-4 pb-6">
        <div>
          <h1 class="text-3xl sm:text-4xl font-bold text-[#0F172A]">Shop All</h1>
          <p class="text-sm text-[#475569] mt-1">{length(@products)} products</p>
        </div>
      </div>

      <%!-- Main content: sidebar + products --%>
      <div class="flex gap-8 pb-16">
        <%!-- Filter sidebar (desktop) --%>
        <aside class="hidden lg:block w-64 flex-shrink-0">
          <div class="sticky top-24 space-y-6">
            <%!-- Category filter --%>
            <div>
              <h3 class="text-lg font-semibold text-[#0F172A] mb-3">Category</h3>
              <div class="space-y-2.5">
                <label class="flex items-center gap-3 cursor-pointer group">
                  <input
                    type="radio"
                    name="category"
                    checked={is_nil(@selected_category)}
                    phx-click="filter_category"
                    phx-value-category_id="all"
                    class="w-[18px] h-[18px] accent-[#1C1917] cursor-pointer"
                  />
                  <span class={"text-sm group-hover:text-[#0F172A] transition-colors #{if is_nil(@selected_category), do: "text-[#0F172A] font-medium", else: "text-[#475569]"}"}>
                    All
                  </span>
                </label>
                <label :for={cat <- @categories} class="flex items-center gap-3 cursor-pointer group">
                  <input
                    type="radio"
                    name="category"
                    checked={@selected_category == cat.id}
                    phx-click="filter_category"
                    phx-value-category_id={cat.id}
                    class="w-[18px] h-[18px] accent-[#1C1917] cursor-pointer"
                  />
                  <span class={"text-sm group-hover:text-[#0F172A] transition-colors #{if @selected_category == cat.id, do: "text-[#0F172A] font-medium", else: "text-[#475569]"}"}>
                    {cat.name}
                  </span>
                </label>
              </div>
            </div>
          </div>
        </aside>

        <%!-- Product grid area --%>
        <div class="flex-1 min-w-0">
          <%!-- Mobile filter + Sort bar --%>
          <div class="flex items-center gap-3 mb-6 lg:mb-6">
            <%!-- Mobile category filter --%>
            <div class="lg:hidden flex-1">
              <select
                phx-change="filter_category_select"
                name="category_id"
                class="w-full px-3 py-2.5 border border-[#E2E8F0] rounded-lg text-sm text-[#0F172A] bg-white focus:outline-none focus:ring-2 focus:ring-[#B45309] appearance-none bg-[url('data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20width%3D%2212%22%20height%3D%2212%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20stroke%3D%22%2344403C%22%20stroke-width%3D%222%22%3E%3Cpath%20d%3D%22M6%209l6%206%206-6%22/%3E%3C/svg%3E')] bg-no-repeat bg-[right_12px_center]"
              >
                <option value="all" selected={is_nil(@selected_category)}>All Categories</option>
                <option
                  :for={cat <- @categories}
                  value={cat.id}
                  selected={@selected_category == cat.id}
                >
                  {cat.name}
                </option>
              </select>
            </div>

            <%!-- Search --%>
            <form phx-change="search" class="flex-1 lg:max-w-sm">
              <div class="relative">
                <svg
                  class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#94A3B8]"
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
                  class="w-full pl-9 pr-4 py-2.5 border border-[#E2E8F0] rounded-lg text-sm text-[#0F172A] bg-white placeholder:text-[#94A3B8] focus:outline-none focus:ring-2 focus:ring-[#B45309] focus:border-transparent"
                />
              </div>
            </form>
          </div>

          <%!-- Products --%>
          <%= if @products == [] do %>
            <div class="py-20 text-center">
              <svg
                class="w-16 h-16 mx-auto text-[#E2E8F0] mb-4"
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
              <p class="text-[#475569]">No products found.</p>
              <button
                :if={@search_query != "" || @selected_category}
                phx-click="filter_category"
                phx-value-category_id="all"
                class="mt-4 text-sm font-medium text-[#B45309] hover:text-[#92400E] transition-colors"
              >
                Clear filters
              </button>
            </div>
          <% else %>
            <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-4 lg:gap-5">
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

    <.bottom_nav store_slug={@store.slug} active_tab={:search} cart_count={@cart_count} />
    """
  end
end
