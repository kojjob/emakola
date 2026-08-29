defmodule Emakola.Themes.Depot.ProductList do
  @moduledoc """
  Depot theme — full catalogue as an order table.

  The same ledger language as the home order sheet, but rows link through
  to the product page: the list LiveView loads no variants and has no
  `add_to_cart` handler, so quick-adding here would crash the live
  storefront. What the list read really carries — title, price range,
  `variant_count` — is what the table shows. Search (`search`), category
  filters (`filter_category`) and pagination (`load_more`) wire only the
  handlers the LiveView really has.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Depot.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAF9F7]">
      <Shared.depot_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <div class="border-b border-[#E7E5E1] bg-white">
        <div class="mx-auto max-w-[1120px] px-4 py-8 sm:px-6 sm:py-10 lg:px-8">
          <p class="mb-2 font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-zinc-500">
            {@store.name}
          </p>
          <h1 class="text-3xl font-bold tracking-tight text-zinc-900 [font-family:var(--dt-heading-font,inherit)] sm:text-4xl">
            Catalogue
          </h1>
          <p class="mt-2 text-sm tabular-nums text-zinc-600">
            {@products_count} items shown
          </p>
        </div>
      </div>

      <div class="mx-auto max-w-[1120px] px-4 pb-16 pt-6 sm:px-6 lg:px-8">
        <div class="mb-5 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <form phx-change="search" class="w-full md:max-w-xs">
            <label for="depot-catalogue-search" class="sr-only">Search the catalogue</label>
            <div class="relative">
              <svg
                class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                />
              </svg>
              <input
                id="depot-catalogue-search"
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search by item"
                phx-debounce="300"
                class="w-full border border-zinc-300 bg-white py-2.5 pl-9 pr-4 text-sm text-zinc-900 placeholder-zinc-400 focus:border-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
              />
            </div>
          </form>

          <div
            :if={@categories != []}
            class="-mx-4 flex items-center gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
          >
            <button
              phx-click="filter_category"
              phx-value-category_id="all"
              class={[
                "flex-shrink-0 border px-3.5 py-2 text-[0.8125rem] font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
                if(is_nil(@selected_category),
                  do: "border-zinc-900 bg-zinc-900 text-white",
                  else: "border-zinc-300 bg-white text-zinc-700 hover:border-zinc-900"
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
                "flex-shrink-0 border px-3.5 py-2 text-[0.8125rem] font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
                if(@selected_category == category.id,
                  do: "border-zinc-900 bg-zinc-900 text-white",
                  else: "border-zinc-300 bg-white text-zinc-700 hover:border-zinc-900"
                )
              ]}
            >
              {category.name}
            </button>
          </div>
        </div>

        <div class="overflow-x-auto border border-[#E7E5E1] bg-white shadow-sm">
          <table class="w-full text-left">
            <thead>
              <tr class="bg-[#18181B] text-white">
                <th
                  scope="col"
                  class="py-2.5 pl-4 pr-3 text-left font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-white/70 sm:pl-5"
                >
                  Item
                </th>
                <th
                  scope="col"
                  class="px-3 py-2.5 text-right font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-white/70"
                >
                  Price
                </th>
                <th scope="col" class="py-2.5 pl-3 pr-4 sm:pr-5">
                  <span class="sr-only">View item</span>
                </th>
              </tr>
            </thead>
            <tbody id="product-list" phx-update="stream">
              <tr id="product-list-empty" class="hidden only:table-row">
                <td
                  colspan="3"
                  class="border border-dashed border-[#D8D4CC] bg-white px-6 py-14 text-center sm:py-16"
                >
                  <h2 class="mb-1.5 text-lg font-bold tracking-tight text-zinc-900">
                    No items match
                  </h2>
                  <p class="mx-auto mb-6 max-w-sm text-sm leading-relaxed text-zinc-600">
                    Nothing in the catalogue matches your search. Try another term or clear the filters.
                  </p>
                  <button
                    :if={@search_query != "" || @selected_category}
                    phx-click="filter_category"
                    phx-value-category_id="all"
                    class="inline-flex items-center border border-[#E7E5E1] shadow-sm px-5 py-2.5 text-sm font-bold text-zinc-900 hover:bg-zinc-900 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
                  >
                    Clear all filters
                  </button>
                </td>
              </tr>
              <tr
                :for={{dom_id, %{product: product}} <- @streams.products}
                id={dom_id}
                class="group border-b border-[#E7E5E1] last:border-b-0 hover:bg-[#FAF9F7] motion-safe:transition-colors"
              >
                <td class="border-l-2 border-transparent py-3 pl-4 pr-3 group-hover:border-[#C2410C] sm:pl-5">
                  <div class="flex items-center gap-3">
                    <.optimized_image
                      :if={Shared.first_image(product)}
                      src={Shared.first_image(product)}
                      alt=""
                      width={96}
                      height={96}
                      class="h-11 w-11 flex-shrink-0 border border-[#E7E5E1] object-cover"
                    />
                    <span
                      :if={!Shared.first_image(product)}
                      aria-hidden="true"
                      class="flex h-11 w-11 flex-shrink-0 items-center justify-center border border-[#E7E5E1] bg-[#F1EFEA] font-mono text-sm font-semibold text-[#A8A29E]"
                    >
                      {String.first(product.title)}
                    </span>
                    <a
                      href={store_path(@store.slug, "/products/#{product.slug}")}
                      class="min-w-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#C2410C] focus-visible:ring-offset-2"
                    >
                      <span class="block text-sm font-semibold leading-snug text-zinc-900">
                        {product.title}
                      </span>
                      <span
                        :if={Shared.variant_count(product) > 1}
                        class="mt-0.5 block text-xs tabular-nums text-zinc-500"
                      >
                        {Shared.variant_count(product)} options
                      </span>
                    </a>
                  </div>
                </td>
                <td class="px-3 py-3 text-right text-sm font-bold tabular-nums text-zinc-900">
                  {Currency.format_price_range(
                    product.min_price,
                    product.max_price,
                    @store.currency
                  )}
                </td>
                <td class="py-3 pl-3 pr-4 text-right sm:pr-5">
                  <a
                    href={store_path(@store.slug, "/products/#{product.slug}")}
                    aria-label={"View #{product.title}"}
                    class="inline-flex h-9 items-center gap-1 border border-zinc-300 px-3 text-xs font-bold text-zinc-800 hover:border-zinc-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
                  >
                    View
                    <svg
                      class="h-3 w-3"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2.5"
                      aria-hidden="true"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M8.25 4.5l7.5 7.5-7.5 7.5"
                      />
                    </svg>
                  </a>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div :if={@has_more} class="mt-6 text-center">
          <button
            phx-click="load_more"
            class="inline-flex items-center gap-2 border border-[#E7E5E1] shadow-sm px-8 py-3 text-sm font-bold text-zinc-900 hover:bg-zinc-900 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            Load more
          </button>
        </div>
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} />
    <Shared.depot_bottom_nav store={@store} cart_count={@cart_count} active={:catalogue} />
    """
  end
end
