defmodule Emakola.Themes.Ntoma.ProductList do
  @moduledoc """
  Ntoma theme — product list page renderer.

  An editorial collection page: Ntoma's banner nav (the cart stays
  reachable on desktop), an oversized serif header, category filter pills
  and live search, the browse-only card grid, and load-more pagination.

  Cards here render without add-to-cart — `ProductListLive` owns no
  `add_to_cart` handler, so a buy button on this page would crash the
  live storefront.
  """
  use Phoenix.Component

  alias Emakola.Themes.Ntoma.Shared

  def render(assigns) do
    ~H"""
    <Shared.ntoma_nav store={@store} categories={@categories} cart_count={@cart_count} />

    <div class="bg-[#FAF4EA]">
      <div class="border-b border-[#E6D5B8]">
        <div class="mx-auto max-w-[1280px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
          <p class="mb-3 text-[0.6875rem] font-bold uppercase tracking-[0.24em] text-[#B97C10]">
            {@store.name}
          </p>
          <h1 class="break-words text-[clamp(2.5rem,7vw,5rem)] font-semibold uppercase leading-[0.92] tracking-[-0.01em] text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]">
            The Collection
          </h1>
          <p class="mt-4 text-sm text-[#7A6248]">
            {@products_count} pieces
          </p>
        </div>
      </div>

      <div class="mx-auto max-w-[1280px] px-4 py-8 pb-24 sm:px-6 sm:pb-16 lg:px-8">
        <div class="mb-8 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div class="flex items-center gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <button
              phx-click="filter_category"
              phx-value-category_id="all"
              class={[
                "flex-shrink-0 cursor-pointer border px-4 py-2 text-[0.8125rem] font-semibold uppercase tracking-[0.08em] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-colors",
                if(is_nil(@selected_category),
                  do: "border-[#2B1708] bg-[#2B1708] text-[#FAF4EA]",
                  else:
                    "border-[#E6D5B8] bg-[#FFFBF2] text-[#7A6248] hover:border-[#2B1708] hover:text-[#2B1708]"
                )
              ]}
            >
              All
            </button>
            <button
              :for={category <- @categories}
              phx-click="filter_category"
              phx-value-category_id={category.id}
              class={[
                "flex-shrink-0 cursor-pointer border px-4 py-2 text-[0.8125rem] font-semibold uppercase tracking-[0.08em] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-colors",
                if(@selected_category == category.id,
                  do: "border-[#2B1708] bg-[#2B1708] text-[#FAF4EA]",
                  else:
                    "border-[#E6D5B8] bg-[#FFFBF2] text-[#7A6248] hover:border-[#2B1708] hover:text-[#2B1708]"
                )
              ]}
            >
              {category.name}
            </button>
          </div>

          <form phx-change="search" class="w-full lg:max-w-xs">
            <label for="ntoma-list-search" class="sr-only">Search pieces</label>
            <input
              id="ntoma-list-search"
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search pieces..."
              phx-debounce="300"
              class="w-full border border-[#E6D5B8] bg-white px-4 py-2.5 text-sm text-[#2B1708] placeholder-[#A08863] focus:outline-none focus:ring-2 focus:ring-[#2B1708]"
            />
          </form>
        </div>

        <div
          id="product-list"
          phx-update="stream"
          class="grid grid-cols-2 gap-x-3 gap-y-8 sm:grid-cols-3 sm:gap-x-4 xl:grid-cols-4 xl:gap-x-5"
        >
          <div
            id="product-list-empty"
            class="col-span-full hidden border-2 border-dashed border-[#E6D5B8] bg-[#FFFBF2] px-6 py-20 text-center only:block"
          >
            <h2 class="mb-2 text-xl font-semibold text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-2xl">
              Nothing matches
            </h2>
            <p class="mx-auto mb-6 max-w-sm text-sm leading-relaxed text-[#7A6248]">
              We couldn't find any pieces for that. Try another search or browse everything.
            </p>
            <button
              :if={@search_query != "" || @selected_category}
              phx-click="filter_category"
              phx-value-category_id="all"
              class="inline-flex cursor-pointer items-center gap-2 border border-[#2B1708] px-6 py-2.5 text-sm font-semibold uppercase tracking-[0.1em] text-[#2B1708] hover:bg-[#2B1708] hover:text-[#FAF4EA] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              Clear all filters
            </button>
          </div>
          <div
            :for={{dom_id, %{product: product}} <- @streams.products}
            id={dom_id}
            class="contents"
          >
            <Shared.product_card
              product={product}
              store={@store}
              show_add={false}
            />
          </div>
        </div>

        <div :if={@has_more} class="mt-12 text-center">
          <button
            phx-click="load_more"
            class="inline-flex cursor-pointer items-center gap-2 border border-[#2B1708] px-8 py-3 text-sm font-semibold uppercase tracking-[0.1em] text-[#2B1708] hover:bg-[#2B1708] hover:text-[#FAF4EA] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            Load more
            <svg
              class="h-4 w-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19.5 13.5L12 21m0 0l-7.5-7.5M12 21V3"
              />
            </svg>
          </button>
        </div>
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} />
    <Shared.ntoma_bottom_nav store={@store} cart_count={@cart_count} active={:search} />
    """
  end
end
