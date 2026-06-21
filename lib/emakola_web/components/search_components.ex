defmodule EmakolaWeb.SearchComponents do
  @moduledoc """
  Search overlay components for the storefront.

  Provides a full-screen overlay on mobile and a dropdown on desktop with
  live autocomplete. Shows product thumbnails, titles, and prices with a
  maximum of 6 results and a "View all" link.

  Design tokens:
  - Background: #FAFAF9 (cream-50)
  - Accent: #B45309 (amber-700)
  - Dark surfaces: #1C1917 (stone-900)
  - Cards: rounded-[20px]
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias EmakolaWeb.Helpers.Currency

  @max_results 6

  @doc """
  Full-screen search overlay (mobile) / dropdown (desktop).

  Expects the parent LiveView to assign:
  - `search_query` — the current query string
  - `search_results` — list of product maps (loaded with :images, :min_price)
  - `searching` — boolean, true while a search request is in-flight
  - `store` — the current store map
  """
  attr :search_query, :string, default: ""
  attr :search_results, :list, default: []
  attr :searching, :boolean, default: false
  attr :store, :map, required: true
  attr :total_results, :integer, default: 0

  def search_overlay(assigns) do
    assigns = assign(assigns, :max_results, @max_results)

    ~H"""
    <div
      id="search-overlay"
      class="fixed inset-0 z-[60] hidden"
      phx-window-keydown={hide_search()}
      phx-key="Escape"
    >
      <%!-- Backdrop --%>
      <div
        class="absolute inset-0 bg-black/40 backdrop-blur-sm"
        phx-click={hide_search()}
        aria-hidden="true"
      >
      </div>

      <%!-- Search panel: full-screen on mobile, centered dropdown on desktop --%>
      <div class="relative h-full sm:h-auto sm:max-w-xl sm:mx-auto sm:mt-20">
        <div class="h-full sm:h-auto bg-[#FAFAF9] sm:rounded-[20px] sm:shadow-2xl sm:border sm:border-[#E2E8F0] flex flex-col sm:max-h-[70vh]">
          <%!-- Search input header --%>
          <div class="flex items-center gap-3 px-4 sm:px-5 py-3.5 border-b border-[#E2E8F0] bg-white sm:rounded-t-[20px]">
            <svg
              class="w-5 h-5 text-[#94A3B8] flex-shrink-0"
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
              id="search-input"
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search products..."
              phx-keyup="search_overlay"
              phx-debounce="300"
              autocomplete="off"
              autofocus
              class="flex-1 text-[0.9375rem] text-[#0F172A] placeholder:text-[#94A3B8] bg-transparent border-none focus:outline-none focus:ring-0"
            />
            <button
              type="button"
              phx-click={hide_search()}
              class="p-1.5 rounded-lg hover:bg-[#F1F5F9] transition-colors text-[#64748B]"
              aria-label="Close search"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <%!-- Results area --%>
          <div class="flex-1 overflow-y-auto">
            <%!-- Loading skeleton --%>
            <div :if={@searching} class="p-4 space-y-3">
              <.search_skeleton />
              <.search_skeleton />
              <.search_skeleton />
            </div>

            <%!-- Empty state: no query entered --%>
            <div :if={!@searching && @search_query == ""} class="py-12 px-4 text-center">
              <div class="w-14 h-14 mx-auto bg-white rounded-full flex items-center justify-center border border-[#E2E8F0] mb-3">
                <svg
                  class="w-7 h-7 text-[#94A3B8]"
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
              </div>
              <p class="text-sm font-medium text-[#64748B]">
                Search for products by name
              </p>
            </div>

            <%!-- No results --%>
            <div
              :if={!@searching && @search_query != "" && @search_results == []}
              class="py-12 px-4 text-center"
            >
              <div class="w-14 h-14 mx-auto bg-white rounded-full flex items-center justify-center border border-[#E2E8F0] mb-3">
                <svg
                  class="w-7 h-7 text-[#94A3B8]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.182 16.318A4.486 4.486 0 0 0 12.016 15a4.486 4.486 0 0 0-3.198 1.318M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Z"
                  />
                </svg>
              </div>
              <p class="text-sm font-semibold text-[#0F172A] mb-1">
                No results found
              </p>
              <p class="text-xs text-[#64748B]">
                Try a different search term
              </p>
            </div>

            <%!-- Search results --%>
            <div :if={!@searching && @search_results != []} class="py-2">
              <a
                :for={product <- Enum.take(@search_results, @max_results)}
                href={"/@#{@store.slug}/products/#{product.slug}"}
                class="flex items-center gap-3.5 px-4 sm:px-5 py-3 hover:bg-white transition-colors"
              >
                <div class="w-12 h-12 rounded-xl bg-[#F1F5F9] flex-shrink-0 overflow-hidden border border-[#E2E8F0]">
                  <img
                    :if={first_image(product)}
                    src={first_image(product)}
                    alt={product.title}
                    class="w-full h-full object-cover"
                    loading="lazy"
                  />
                  <div
                    :if={!first_image(product)}
                    class="w-full h-full flex items-center justify-center"
                  >
                    <svg
                      class="w-5 h-5 text-[#94A3B8]"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                  </div>
                </div>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-semibold text-[#0F172A] truncate">
                    {product.title}
                  </p>
                  <p class="text-xs font-medium text-store-accent">
                    {Currency.format_price(product.min_price || 0, @store.currency)}
                  </p>
                </div>
                <svg
                  class="w-4 h-4 text-[#CBD5E1] flex-shrink-0"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="m9 5 7 7-7 7" />
                </svg>
              </a>

              <%!-- View all results link --%>
              <div
                :if={@total_results > @max_results}
                class="px-4 sm:px-5 py-3 border-t border-[#E2E8F0]"
              >
                <a
                  href={"/@#{@store.slug}/products?q=#{URI.encode_www_form(@search_query)}"}
                  class="flex items-center justify-center gap-2 py-2.5 w-full rounded-xl bg-white border border-[#E2E8F0] text-sm font-semibold text-[#0F172A] hover:bg-[#F8FAFC] hover:border-[#CBD5E1] transition-all"
                >
                  View all {@total_results} results
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
                      d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3"
                    />
                  </svg>
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Skeleton loading animation for search results.
  """
  def search_skeleton(assigns) do
    ~H"""
    <div class="flex items-center gap-3.5 animate-pulse">
      <div class="w-12 h-12 rounded-xl bg-[#E2E8F0]"></div>
      <div class="flex-1 space-y-2">
        <div class="h-3.5 bg-[#E2E8F0] rounded-full w-3/4"></div>
        <div class="h-3 bg-[#E2E8F0] rounded-full w-1/3"></div>
      </div>
    </div>
    """
  end

  @doc """
  JS command to show the search overlay with animation.
  """
  def show_search do
    JS.show(
      to: "#search-overlay",
      transition: {"transition-opacity duration-200", "opacity-0", "opacity-100"}
    )
    |> JS.focus(to: "#search-input")
  end

  @doc """
  JS command to hide the search overlay with animation.
  """
  def hide_search do
    JS.hide(
      to: "#search-overlay",
      transition: {"transition-opacity duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.push("close_search")
  end

  # Extract first image URL from a product's images association.
  defp first_image(product) do
    case product do
      %{images: [%{thumbnail_url: url} | _]} when is_binary(url) -> url
      %{images: [%{url: url} | _]} when is_binary(url) -> url
      _ -> nil
    end
  end
end
