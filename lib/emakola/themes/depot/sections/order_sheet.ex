defmodule Emakola.Themes.Depot.Sections.OrderSheet do
  @moduledoc """
  Depot's signature — the quick-order sheet.

  A dense, scannable table: item, SKU, stock on hand, price, add. A
  returning buyer fills an order without leaving the screen. Every column
  is a field `Emakola.Catalog` really exposes; single-variant rows
  quick-add one unit via the home page's `add_to_cart` handler, and
  multi-variant rows route to the product page instead of blind-adding an
  arbitrary variant. Zero images by design — the table is fast on metered
  data because there is nothing to load but text.

  A store with zero products renders an intentional stocking-up state:
  a brand-new depot must never look broken to its first visitor.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Depot.Shared

  @impl true
  def key, do: "depot/order_sheet"
  @impl true
  def label, do: "Order sheet"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Order sheet"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@products != []}
      class="bg-zinc-50 px-4 py-6 sm:px-6 sm:py-8 lg:px-8"
      aria-labelledby="depot-order-sheet-heading"
    >
      <div class="mx-auto max-w-[1120px]">
        <div class="mb-4 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
          <h2
            id="depot-order-sheet-heading"
            class="text-lg font-bold tracking-tight text-zinc-900 [font-family:var(--dt-heading-font,inherit)]"
          >
            {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Order sheet"}
          </h2>
          <p class="text-xs text-zinc-500">
            Add puts one unit in your order — open an item for quantities and options.
          </p>
        </div>
        <div class="overflow-x-auto border-2 border-zinc-900 bg-white">
          <table class="w-full text-left">
            <thead>
              <tr class="border-b-2 border-zinc-900">
                <th
                  scope="col"
                  class="py-2.5 pl-4 pr-3 text-left font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-zinc-500 sm:pl-5"
                >
                  Item
                </th>
                <th
                  scope="col"
                  class="hidden px-3 py-2.5 text-left font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-zinc-500 sm:table-cell"
                >
                  SKU
                </th>
                <th
                  scope="col"
                  class="hidden px-3 py-2.5 text-left font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-zinc-500 md:table-cell"
                >
                  Stock
                </th>
                <th
                  scope="col"
                  class="px-3 py-2.5 text-right font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-zinc-500"
                >
                  Price
                </th>
                <th scope="col" class="py-2.5 pl-3 pr-4 sm:pr-5">
                  <span class="sr-only">Add to order</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <Shared.order_row :for={product <- @products} product={product} store={@store} />
            </tbody>
          </table>
        </div>
        <div class="mt-4 text-right">
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex items-center gap-1.5 text-sm font-bold text-zinc-900 underline decoration-2 underline-offset-4 hover:text-zinc-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            Full catalogue
            <svg
              class="h-3.5 w-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
              />
            </svg>
          </a>
        </div>
      </div>
    </section>
    <section
      :if={@products == []}
      class="bg-zinc-50 px-4 py-6 sm:px-6 sm:py-8 lg:px-8"
      aria-labelledby="depot-order-sheet-empty-heading"
    >
      <div class="mx-auto max-w-[1120px] border-2 border-dashed border-zinc-300 bg-white px-6 py-14 text-center sm:py-16">
        <div class="mx-auto mb-4 flex h-14 w-14 items-center justify-center border-2 border-zinc-200">
          <svg
            class="h-6 w-6 text-zinc-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25z"
            />
          </svg>
        </div>
        <h2
          id="depot-order-sheet-empty-heading"
          class="mb-1.5 text-lg font-bold tracking-tight text-zinc-900"
        >
          The depot is being stocked
        </h2>
        <p class="mx-auto max-w-sm text-sm leading-relaxed text-zinc-600">
          {@store.name} hasn't listed any items yet — check back soon.
        </p>
      </div>
    </section>
    """
  end
end
