defmodule Emakola.Themes.Fie.Sections.CollectionIndex do
  @moduledoc """
  Fie home collection index — the catalogue's table of contents.

  Each collection is a full-width hairline row: its real position in the
  browse order as a zero-padded numeral, its name in the heading face,
  and an arrow into the category page. The numbering encodes true
  structure (a décor catalogue genuinely is an indexed collection), so
  when the store has no collections the section withdraws entirely
  rather than render fake numbers.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fie.Components

  @impl true
  def key, do: "fie/collections"
  @impl true
  def label, do: "Collection index"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Collections"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@categories != []}
      class="border-b border-[#EBDAD3] bg-[#FDFCFB]"
      aria-labelledby="fie-collections-heading"
    >
      <div class="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <h2
          id="fie-collections-heading"
          class="mb-6 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500"
        >
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Collections"}
        </h2>
        <ol>
          <li
            :for={{category, index} <- Enum.with_index(@categories, 1)}
            class="border-t border-[#EBDAD3] last:border-b"
          >
            <a
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="group flex min-h-[56px] items-center gap-6 py-4 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 sm:gap-10"
            >
              <span class="w-8 text-sm font-medium tabular-nums text-stone-400 group-hover:text-store-accent [font-family:'Space_Grotesk','Inter',sans-serif] motion-safe:transition-colors">
                {Components.index_no(index)}
              </span>
              <span class="min-w-0 flex-1 truncate text-xl font-medium tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif] sm:text-2xl">
                {category.name}
              </span>
              <svg
                class="h-5 w-5 flex-shrink-0 text-stone-400 group-hover:text-stone-900 motion-safe:transition-[color,transform] motion-safe:group-hover:translate-x-1"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.8"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
          </li>
        </ol>
      </div>
    </section>
    """
  end
end
