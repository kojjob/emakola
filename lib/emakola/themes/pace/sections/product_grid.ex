defmodule Emakola.Themes.Pace.Sections.ProductGrid do
  @moduledoc """
  Pace home "The Lineup" grid — night-gradient cards in 2 / 3 / 4
  columns.

  A store with zero products renders an intentional warming-up state
  instead of nothing — a brand-new store must never look broken to its
  first visitor (or to the merchant previewing it).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Pace.Components

  @impl true
  def key, do: "pace/product_grid"
  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "The Lineup"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@products != []}
      class="px-5 py-4 sm:px-8 sm:py-5 lg:px-10"
      aria-labelledby="pace-lineup-heading"
    >
      <div class="mx-auto max-w-[1280px]">
        <h2
          id="pace-lineup-heading"
          class="pace-display mb-4 text-xl font-bold uppercase italic tracking-tight text-slate-950"
        >
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "The Lineup"}
        </h2>
        <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 lg:grid-cols-4 lg:gap-5">
          <Components.product_card :for={product <- @products} product={product} store={@store} />
        </div>
      </div>
    </section>
    <section
      :if={@products == []}
      class="px-5 py-4 sm:px-8 sm:py-5 lg:px-10"
      aria-labelledby="pace-grid-empty-heading"
    >
      <div class="mx-auto max-w-[1280px] rounded-[24px] border-2 border-dashed border-slate-200 bg-[#F1F6FA] px-6 py-14 text-center sm:py-16">
        <div class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full border border-slate-200 bg-white">
          <svg
            class="h-6 w-6 text-slate-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
        </div>
        <h2
          id="pace-grid-empty-heading"
          class="pace-display mb-1.5 text-xl font-bold uppercase italic tracking-tight text-slate-950"
        >
          The lineup is warming up
        </h2>
        <p class="mx-auto max-w-sm text-sm leading-relaxed text-slate-600">
          {@store.name} hasn't added any products yet — check back soon.
        </p>
      </div>
    </section>
    """
  end
end
