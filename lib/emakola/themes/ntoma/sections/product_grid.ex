defmodule Emakola.Themes.Ntoma.Sections.ProductGrid do
  @moduledoc """
  Ntoma home grid — the latest pieces in a 2 / 3 / 4 column editorial grid.
  Cards carry the placeholder-first treatment, the garment-label price tag,
  and add-to-cart.

  The grid shows the catalogue minus the featured piece, so nothing on the
  page appears twice; with a single piece the featured card carries it and
  the grid stays out of the way. A store with zero products renders an
  intentional setting-up state instead of nothing — a brand-new atelier
  must never look broken to its first visitor (or to the merchant
  previewing it).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Ntoma.Shared

  @impl true
  def key, do: "ntoma/product_grid"
  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Latest pieces"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.grid_products != []}
      class="px-4 py-10 sm:px-6 sm:py-14 lg:px-8"
      aria-labelledby="ntoma-grid-heading"
    >
      <div class="mx-auto max-w-[1280px]">
        <h2
          id="ntoma-grid-heading"
          class="mb-6 text-2xl font-semibold uppercase tracking-tight text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-3xl"
        >
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Latest pieces"}
        </h2>
        <div class="grid grid-cols-2 gap-x-3 gap-y-8 md:grid-cols-3 md:gap-x-4 lg:grid-cols-4 lg:gap-x-5">
          <Shared.product_card
            :for={product <- @layout.grid_products}
            product={product}
            store={@store}
          />
        </div>
      </div>
    </section>
    <section
      :if={@layout.count == 0}
      class="px-4 py-10 sm:px-6 sm:py-14 lg:px-8"
      aria-labelledby="ntoma-grid-empty-heading"
    >
      <div class="mx-auto max-w-[1280px] border-2 border-dashed border-[#E6D5B8] bg-[#FFFBF2] px-6 py-14 text-center sm:py-16">
        <h2
          id="ntoma-grid-empty-heading"
          class="mb-2 text-xl font-semibold text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-2xl"
        >
          The first collection is on its way
        </h2>
        <p class="mx-auto max-w-sm text-sm leading-relaxed text-[#7A6248]">
          {@store.name} is stitching its first pieces — check back soon.
        </p>
      </div>
    </section>
    """
  end
end
