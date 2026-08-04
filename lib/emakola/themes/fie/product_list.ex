defmodule Emakola.Themes.Fie.ProductList do
  @moduledoc """
  Fie theme — product list page: the full catalogue.

  Breadcrumb, the catalogue heading with its true piece count, search
  (`search`), collection filters (`filter_category`), the numbered plate
  grid, and `load_more` pagination. Numbers continue across pages as
  products accumulate, so the index stays true to browse order. All
  events are handled by `ProductListLive`.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fie.Components
  alias Emakola.Themes.Fie.Shared

  def render(assigns) do
    ~H"""
    <div class="bg-[#FDFCFB]">
      <Shared.theme_styles theme={@theme} />
      <%!-- Theme banner nav: the bottom bar below is mobile-only, so without
      this the cart is unreachable from the list page on desktop. --%>
      <Shared.fie_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <div class="mx-auto max-w-[1200px] px-4 sm:px-6 lg:px-8">
        <nav aria-label="Breadcrumb" class="pt-6">
          <ol class="flex items-center gap-2 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
            <li>
              <a
                href={store_path(@store.slug, "/")}
                class="hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
              >
                Home
              </a>
            </li>
            <li aria-hidden="true">/</li>
            <li class="text-stone-900" aria-current="page">Catalogue</li>
          </ol>
        </nav>

        <div class="flex flex-col gap-6 border-b border-[#EBDAD3] pb-8 pt-8 sm:pt-10 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 class="text-4xl font-medium tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif] sm:text-5xl">
              The Catalogue
            </h1>
            <p class="mt-3 text-sm tabular-nums text-stone-500">
              {Components.count_label(@products_count, "piece")} on this page
            </p>
          </div>

          <form phx-change="search" class="w-full lg:max-w-xs">
            <label for="fie-catalogue-search" class="sr-only">Search the catalogue</label>
            <div class="relative">
              <svg
                class="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-stone-400"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                />
              </svg>
              <input
                id="fie-catalogue-search"
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search the catalogue..."
                phx-debounce="300"
                class="min-h-[48px] w-full border border-[#EBDAD3] bg-white py-2.5 pl-10 pr-4 text-sm text-stone-900 placeholder-stone-400 focus:border-stone-900 focus:outline-none focus:ring-2 focus:ring-stone-900/15 motion-safe:transition-colors"
              />
            </div>
          </form>
        </div>

        <div
          :if={@categories != []}
          class="flex items-center gap-2 overflow-x-auto border-b border-[#EBDAD3] py-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
          role="group"
          aria-label="Filter by collection"
        >
          <button
            phx-click="filter_category"
            phx-value-category_id="all"
            class={[
              "min-h-[44px] flex-shrink-0 border px-4 py-2 text-[0.8125rem] font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
              if(is_nil(@selected_category),
                do: "border-stone-900 bg-stone-900 text-white",
                else:
                  "border-[#EBDAD3] bg-white text-stone-600 hover:border-stone-400 hover:text-stone-900"
              )
            ]}
          >
            All
          </button>
          <button
            :for={{category, index} <- Enum.with_index(@categories, 1)}
            phx-click="filter_category"
            phx-value-category_id={category.id}
            class={[
              "min-h-[44px] flex-shrink-0 border px-4 py-2 text-[0.8125rem] font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
              if(@selected_category == category.id,
                do: "border-stone-900 bg-stone-900 text-white",
                else:
                  "border-[#EBDAD3] bg-white text-stone-600 hover:border-stone-400 hover:text-stone-900"
              )
            ]}
          >
            <span class="mr-1.5 tabular-nums text-[0.6875rem] opacity-60 [font-family:'Space_Grotesk','Inter',sans-serif]">
              {Components.index_no(index)}
            </span>
            {category.name}
          </button>
        </div>

        <div class="pb-16 pt-8 sm:pb-20">
          <%!-- Link-only plates: ProductListLive has no add_to_cart handler,
          so a quick-add here would crash the live page. --%>
          <ol
            id="product-list"
            phx-update="stream"
            class="grid grid-cols-2 gap-x-4 gap-y-8 md:grid-cols-3 md:gap-x-5 lg:grid-cols-4 lg:gap-x-6"
          >
            <li
              id="product-list-empty"
              class="col-span-full hidden border border-[#EBDAD3] bg-[#F7ECE7] px-6 py-16 text-center only:block sm:py-20"
            >
              <span
                class="mb-4 block select-none text-6xl font-medium text-[#D8BCB0] [font-family:'Space_Grotesk','Inter',sans-serif]"
                aria-hidden="true"
              >
                {String.first(@store.name)}
              </span>
              <h2 class="mb-2 text-lg font-medium tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif]">
                Nothing on this page
              </h2>
              <p class="mx-auto mb-6 max-w-sm text-sm leading-relaxed text-stone-600">
                No pieces match your search. Try another word, or open the full catalogue.
              </p>
              <button
                :if={@search_query != "" || @selected_category}
                phx-click="filter_category"
                phx-value-category_id="all"
                class="inline-flex min-h-[48px] cursor-pointer items-center border border-stone-900 bg-white px-6 py-2.5 text-sm font-semibold text-stone-900 hover:bg-stone-900 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
              >
                Clear all filters
              </button>
            </li>
            <li
              :for={{dom_id, %{product: product, position: position}} <- @streams.products}
              id={dom_id}
            >
              <Components.catalogue_plate
                product={product}
                store={@store}
                index={position}
                add_to_cart={false}
              />
            </li>
          </ol>

          <div :if={@has_more} class="mt-12 text-center">
            <button
              phx-click="load_more"
              class="inline-flex min-h-[48px] cursor-pointer items-center gap-2 border border-[#EBDAD3] bg-white px-8 py-3 text-sm font-semibold text-stone-900 hover:border-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              More pages
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
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.fie_bottom_nav store={@store} cart_count={@cart_count} active={:search} />
    """
  end
end
