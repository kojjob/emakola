defmodule Emakola.Themes.Chale.Sections.Categories do
  @moduledoc """
  Chale home category rail — chunky uppercase tags in a horizontal scroll,
  like flyers pinned in a row. Hover inverts to black. Hidden entirely
  when the store has no categories.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "chale/categories"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <nav
      :if={@categories != []}
      class="border-b-2 border-zinc-950 bg-white py-4"
      aria-label="Product categories"
    >
      <div
        class="mx-auto flex max-w-[1280px] gap-3 overflow-x-auto px-4 sm:px-6 lg:px-8 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
        role="list"
      >
        <a
          :for={category <- @categories}
          href={store_path(@store.slug, "/category/#{category.slug}")}
          role="listitem"
          class="flex-shrink-0 border-2 border-zinc-950 bg-white px-4 py-2 text-xs font-bold uppercase tracking-widest text-zinc-950 hover:bg-zinc-950 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors"
        >
          {category.name}
        </a>
      </div>
    </nav>
    """
  end
end
