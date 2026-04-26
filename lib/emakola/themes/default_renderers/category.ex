defmodule Emakola.Themes.DefaultRenderers.Category do
  @moduledoc """
  Default render for the storefront category page.

  Used by `EmakolaWeb.Storefront.CategoryLive` when no theme overrides
  `:render_category`. Includes a private `category_product_card/1`
  function component used in the product grid.

  See `docs/PATTERN-default-renderer-extraction.md`.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents

  alias EmakolaWeb.Helpers.Currency

  @sort_options [
    {"Newest", :newest},
    {"Price: Low to High", :price_asc},
    {"Price: High to Low", :price_desc},
    {"Name: A-Z", :name_asc}
  ]

  def render(assigns) do
    assigns = assign(assigns, :sort_options, @sort_options)

    ~H"""
    <div class="min-h-screen bg-[#FAFAF9]">
      <%!-- Hero Section --%>
      <div class="bg-white border-b border-[#E2E8F0]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
          <%!-- Breadcrumb --%>
          <nav class="flex items-center gap-2 text-xs sm:text-sm font-medium mb-6">
            <a
              href={"/s/#{@store.slug}"}
              class="text-[#94A3B8] hover:text-[#475569] uppercase tracking-wider transition-colors"
            >
              Shop
            </a>
            <%= if @parent_category do %>
              <span class="text-[#CBD5E1]">
                <svg
                  class="w-3.5 h-3.5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
                </svg>
              </span>
              <a
                href={"/s/#{@store.slug}/category/#{@parent_category.slug}"}
                class="text-[#94A3B8] hover:text-[#475569] uppercase tracking-wider transition-colors"
              >
                {@parent_category.name}
              </a>
            <% end %>
            <span class="text-[#CBD5E1]">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
              </svg>
            </span>
            <span class="text-store-accent uppercase tracking-wider">{@category.name}</span>
          </nav>

          <%!-- Hero Title --%>
          <h1 class="text-4xl sm:text-5xl lg:text-6xl font-extrabold tracking-tight leading-[1.1] mb-4">
            <% words = String.split(@category.name, " ", parts: 2) %>
            <%= if length(words) > 1 do %>
              <span class="text-[#0F172A]">{Enum.at(words, 0)}</span>
              <br class="sm:hidden" />
              <span class="text-store-accent">{Enum.at(words, 1)}</span>
            <% else %>
              <span class="text-store-accent">{@category.name}</span>
            <% end %>
          </h1>

          <%!-- Description --%>
          <p
            :if={@category.description}
            class="text-base sm:text-lg text-[#64748B] max-w-2xl leading-relaxed"
          >
            {@category.description}
          </p>
        </div>
      </div>

      <%!-- Filters & Sort Bar --%>
      <div class="sticky top-14 sm:top-16 z-30 bg-[#FAFAF9] border-b border-[#E2E8F0]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <span class="text-sm text-[#64748B]">
              {length(@filtered_products)} {if length(@filtered_products) == 1,
                do: "product",
                else: "products"}
            </span>
          </div>
          <div class="flex items-center gap-3">
            <label
              for="sort-select"
              class="text-xs font-semibold text-[#64748B] uppercase tracking-wider hidden sm:block"
            >
              Sort
            </label>
            <select
              id="sort-select"
              phx-change="sort_products"
              name="sort"
              class="text-sm font-medium text-[#0F172A] bg-white border border-[#E2E8F0] rounded-lg px-3 py-2 pr-8 focus:ring-2 focus:ring-[#B45309]/20 focus:border-[#B45309] cursor-pointer"
            >
              <option
                :for={{label, value} <- @sort_options}
                value={value}
                selected={@sort_by == value}
              >
                {label}
              </option>
            </select>
          </div>
        </div>
      </div>

      <%!-- Product Grid --%>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-10 pb-20 sm:pb-10">
        <%= if @filtered_products == [] do %>
          <div class="text-center py-20">
            <div class="w-20 h-20 rounded-full bg-[#F1F5F9] flex items-center justify-center mx-auto mb-4">
              <svg
                class="w-10 h-10 text-[#CBD5E1]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                />
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-[#0F172A] mb-1">No products yet</h3>
            <p class="text-sm text-[#64748B] mb-6">
              Check back soon for new arrivals in this category.
            </p>
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center gap-2 px-6 py-3 bg-cta-dark text-white text-sm font-semibold rounded-xl hover:bg-[#292524] transition-colors"
            >
              Browse All Products
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
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
          </div>
        <% else %>
          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3 sm:gap-5">
            <.category_product_card
              :for={{product, idx} <- Enum.with_index(@filtered_products)}
              product={product}
              store={@store}
              index={idx}
            />
          </div>
        <% end %>
      </div>

      <%!-- Trust strip --%>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pb-8">
        <div class="flex items-center justify-center gap-6 sm:gap-10 py-6 border-t border-[#E7E5E4]">
          <div class="flex items-center gap-2 text-[#A8A29E]">
            <svg
              class="w-4 h-4 text-[#059669]"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
              />
            </svg>
            <span class="text-xs font-medium">Secure checkout</span>
          </div>
          <div class="flex items-center gap-2 text-[#A8A29E]">
            <svg
              class="w-4 h-4 text-store-accent"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z"
              />
            </svg>
            <span class="text-xs font-medium">MoMo & Card</span>
          </div>
          <div class="hidden sm:flex items-center gap-2 text-[#A8A29E]">
            <svg
              class="w-4 h-4 text-[#7C3AED]"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
              />
            </svg>
            <span class="text-xs font-medium">Fast delivery</span>
          </div>
        </div>
      </div>
    </div>

    <%!-- Footer --%>
    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    <.bottom_nav store_slug={@store.slug} active_tab={:search} cart_count={@cart_count} />
    """
  end

  # ── Category Product Card ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :index, :integer, default: 0

  defp category_product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <div class="group">
      <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="block">
        <div class="relative rounded-xl overflow-hidden mb-3 bg-[#F5F5F4]">
          <img
            :if={@image}
            src={@image}
            alt={@product.title}
            loading="lazy"
            class="w-full aspect-[4/5] object-cover group-hover:scale-105 transition-transform duration-500"
          />
          <div :if={!@image} class="w-full aspect-[4/5] flex items-center justify-center">
            <.image_placeholder size="lg" />
          </div>

          <%!-- Badges --%>
          <div class="absolute top-2.5 left-2.5 flex flex-col gap-1">
            <%= if @product.max_price && @product.min_price && @product.max_price > @product.min_price do %>
              <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-[#DC2626] text-white text-[10px] font-bold uppercase tracking-wider">
                Sale
              </span>
            <% end %>
            <%= cond do %>
              <% @index == 0 -> %>
                <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-[#059669] text-white text-[10px] font-bold uppercase tracking-wider">
                  Popular
                </span>
              <% @product.inserted_at && DateTime.diff(DateTime.utc_now(), @product.inserted_at, :day) < 14 -> %>
                <span class="inline-flex items-center px-2 py-0.5 rounded-full bg-cta-dark text-white text-[10px] font-bold uppercase tracking-wider">
                  New
                </span>
              <% true -> %>
            <% end %>
          </div>

          <%!-- Add to Cart slide-up --%>
          <div class="absolute bottom-0 left-0 right-0 p-2.5 translate-y-full group-hover:translate-y-0 transition-transform duration-300">
            <button
              phx-click="add_to_cart"
              phx-value-product-id={@product.id}
              class="w-full py-2.5 text-[11px] font-semibold uppercase tracking-wider rounded-lg bg-cta-dark text-white cursor-pointer hover:bg-[#292524] transition-colors min-h-[40px]"
            >
              Add to Cart
            </button>
          </div>
        </div>
      </a>

      <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="block px-0.5">
        <h3 class="text-sm font-medium text-cta-dark leading-snug mb-1 line-clamp-1 group-hover:text-store-accent transition-colors">
          {@product.title}
        </h3>
        <div class="flex items-center gap-2">
          <span class="text-sm font-bold" style="color: var(--theme-primary, #B45309);">
            {Currency.format_price(@product.min_price || 0, @store.currency)}
          </span>
          <span
            :if={@product.max_price && @product.max_price > (@product.min_price || 0)}
            class="text-xs text-[#A8A29E] line-through"
          >
            {Currency.format_price(@product.max_price, @store.currency)}
          </span>
        </div>
      </a>
    </div>
    """
  end
end
