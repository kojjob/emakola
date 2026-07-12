defmodule Emakola.Themes.Pace.Sections.CategoryRail do
  @moduledoc """
  Pace home category rail — categories as track lanes: a horizontal
  scroll of outlined pills, each opened by the theme's `///` lane tick.
  Renders nothing when the store has no categories yet; the grid section
  below carries the intentional empty state for a brand-new store.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "pace/category_rail"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <nav :if={@categories != []} class="py-2 sm:py-3" aria-label="Product categories">
      <div
        class="mx-auto flex max-w-[1280px] gap-2.5 overflow-x-auto px-5 sm:px-8 lg:px-10 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
        role="list"
      >
        <a
          :for={category <- @categories}
          href={store_path(@store.slug, "/category/#{category.slug}")}
          class="flex h-11 flex-shrink-0 items-center gap-2 whitespace-nowrap rounded-full border border-slate-200 bg-white px-5 text-xs font-bold uppercase tracking-[0.12em] text-slate-700 hover:border-slate-950 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
          role="listitem"
        >
          <span class="pace-display italic text-store-accent" aria-hidden="true">///</span>
          {category.name}
        </a>
      </div>
    </nav>
    """
  end
end
