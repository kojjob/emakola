defmodule Emakola.Themes.Depot.Sections.CategoryRail do
  @moduledoc """
  Depot home product lines — a flat index of category links, set like
  ledger tabs. Text-only by design: fast, scannable, zero image bytes.
  Renders nothing when the store has no categories; the order sheet
  carries the page's empty state.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "depot/category_rail"
  @impl true
  def label, do: "Product lines"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Browse by line"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <nav
      :if={@categories != []}
      class="border-b border-zinc-200 bg-white px-4 py-6 sm:px-6 sm:py-8 lg:px-8"
      aria-labelledby="depot-lines-heading"
    >
      <div class="mx-auto max-w-[1120px]">
        <h2
          id="depot-lines-heading"
          class="mb-3 font-mono text-xs font-semibold uppercase tracking-[0.16em] text-zinc-500"
        >
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Browse by line"}
        </h2>
        <div class="flex flex-wrap gap-2">
          <a
            :for={category <- @categories}
            href={store_path(@store.slug, "/category/#{category.slug}")}
            class="border border-zinc-300 bg-white px-3.5 py-2 text-[0.8125rem] font-semibold text-zinc-800 hover:border-zinc-900 hover:bg-zinc-900 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            {category.name}
          </a>
        </div>
      </div>
    </nav>
    """
  end
end
