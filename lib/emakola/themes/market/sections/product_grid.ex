defmodule Emakola.Themes.Market.Sections.ProductGrid do
  @moduledoc """
  Market home "Shop All" grid — 2 / 3 / 4 columns. Cards carry the
  placeholder-first treatment, the price chip, and add-to-cart.

  The grid shows the catalogue minus the featured product, so nothing on the
  page appears twice; with a single product the featured card carries it and
  the grid stays out of the way. A store with zero products renders an
  intentional setting-up state instead of nothing — a brand-new stall must
  never look broken to its first visitor (or to the merchant previewing it).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Market.Components

  @impl true
  def key, do: "market/product_grid"
  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Shop All"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.grid_products != []}
      class="px-4 py-4 sm:px-6 sm:py-5 lg:px-8"
      aria-labelledby="shop-all-heading"
    >
      <div class="mx-auto max-w-[1280px]">
        <h2 id="shop-all-heading" class="mb-4 text-lg font-bold tracking-tight text-stone-900">
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Shop All"}
        </h2>
        <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 lg:grid-cols-4 lg:gap-5">
          <Components.product_card
            :for={product <- @layout.grid_products}
            product={product}
            store={@store}
          />
        </div>
      </div>
    </section>
    <section
      :if={@layout.count == 0}
      class="px-4 py-4 sm:px-6 sm:py-5 lg:px-8"
      aria-labelledby="market-grid-empty-heading"
    >
      <div class="mx-auto max-w-[1280px] rounded-[20px] border-2 border-dashed border-stone-200 bg-stone-50 px-6 py-14 text-center sm:py-16">
        <div class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full border border-stone-200 bg-white">
          <svg
            class="h-6 w-6 text-stone-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.5 21v-7.5a.75.75 0 01.75-.75h3a.75.75 0 01.75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349m-16.5 11.65V9.35m0 0a3.001 3.001 0 003.75-.615A2.993 2.993 0 009.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 002.25 1.016c.896 0 1.7-.393 2.25-1.015a3.001 3.001 0 003.75.614m-16.5 0a3.004 3.004 0 01-.621-4.72L4.318 3.44A1.5 1.5 0 015.378 3h13.243a1.5 1.5 0 011.06.44l1.19 1.189a3 3 0 01-.621 4.72m-13.5 8.65h3.75a.75.75 0 00.75-.75V13.5a.75.75 0 00-.75-.75H6.75a.75.75 0 00-.75.75v3.75c0 .414.336.75.75.75z"
            />
          </svg>
        </div>
        <h2
          id="market-grid-empty-heading"
          class="mb-1.5 text-lg font-bold tracking-tight text-stone-900"
        >
          The stall is being set up
        </h2>
        <p class="mx-auto max-w-sm text-sm leading-relaxed text-stone-600">
          {@store.name} hasn't added any products yet — check back soon.
        </p>
      </div>
    </section>
    """
  end
end
