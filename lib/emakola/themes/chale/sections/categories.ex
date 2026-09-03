defmodule Emakola.Themes.Chale.Sections.Categories do
  @moduledoc """
  Chale home category rail — chunky uppercase tags in a horizontal scroll,
  like flyers pinned in a row. Hover inverts to black. Hidden entirely
  when the store has no categories, and until the rack is full enough to
  sort: four or more products.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "chale/categories"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <nav
      :if={@categories != [] and @layout.show_categories?}
      class="border-b border-[#E3E0DA] bg-white py-4"
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
          class="flex-shrink-0 rounded-xl bg-white px-4 py-2 text-xs font-bold uppercase tracking-widest text-[#101114] hover:bg-[#101114] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2547E8] focus-visible:ring-offset-2 motion-safe:transition-colors"
        >
          {category.name}
        </a>
      </div>
    </nav>
    """
  end
end
