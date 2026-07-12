defmodule Emakola.Themes.Ntoma.Sections.CategoryTiles do
  @moduledoc """
  Ntoma asymmetric category tiles — a considered, uneven composition rather
  than a uniform grid, per the locked reference.

  Tiles cycle through a five-step span pattern on a six-column grid: a
  double-height lead tile, two stacked companions, then a wide/narrow pair.
  Each tile is finished before any photography arrives — calico panel, an
  oversized serif initial as watermark, the category name and an arrow.
  A category image, when present, layers over the panel.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Ntoma.Shared

  # Cycle of five: lead tile spans 4x2, two 2-wide companions stack beside
  # it, then a 4-wide and a 2-wide close the block. Mobile stays a plain
  # two-column rhythm with a full-width lead.
  @span_cycle [
    "col-span-2 md:col-span-4 md:row-span-2",
    "md:col-span-2",
    "md:col-span-2",
    "md:col-span-4",
    "md:col-span-2"
  ]

  @impl true
  def key, do: "ntoma/category_tiles"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Shop by category"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@categories != []}
      class="border-b border-[#E6D5B8] bg-[#FAF4EA] px-4 py-10 sm:px-6 sm:py-14 lg:px-8"
      aria-labelledby="ntoma-categories-heading"
    >
      <div class="mx-auto max-w-[1280px]">
        <h2
          id="ntoma-categories-heading"
          class="mb-6 text-2xl font-semibold uppercase tracking-tight text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-3xl"
        >
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "Shop by category"}
        </h2>
        <nav aria-label="Product categories">
          <div class="grid auto-rows-[120px] grid-cols-2 gap-3 md:auto-rows-[150px] md:grid-cols-6 md:gap-4">
            <a
              :for={{category, index} <- Enum.with_index(@categories)}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class={[
                "group relative block overflow-hidden border border-[#E6D5B8] bg-[#F0E3CE] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2",
                tile_span(index)
              ]}
            >
              <span
                class="pointer-events-none absolute -bottom-5 -right-2 select-none text-[6rem] font-semibold leading-none text-[#E2CCA4] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]"
                aria-hidden="true"
              >
                {String.first(category.name)}
              </span>
              <%= if Shared.category_image(category) do %>
                <.optimized_image
                  src={Shared.category_image(category)}
                  alt=""
                  priority={:low}
                  width={480}
                  height={320}
                  class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-500 motion-safe:group-hover:scale-[1.03]"
                />
                <span class="absolute inset-0 bg-gradient-to-t from-[#2B1708]/70 via-transparent to-transparent">
                </span>
              <% end %>
              <span class={[
                "absolute bottom-3 left-3.5 right-3.5 flex items-center justify-between gap-2 text-base font-semibold [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]",
                if(Shared.category_image(category), do: "text-[#FAF4EA]", else: "text-[#2B1708]")
              ]}>
                <span class="truncate">{category.name}</span>
                <svg
                  class="h-4 w-4 flex-shrink-0 motion-safe:transition-transform motion-safe:group-hover:translate-x-1"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                  />
                </svg>
              </span>
            </a>
          </div>
        </nav>
      </div>
    </section>
    """
  end

  defp tile_span(index), do: Enum.at(@span_cycle, rem(index, length(@span_cycle)))
end
