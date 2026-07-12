defmodule Emakola.Themes.Dede.Sections.Categories do
  @moduledoc """
  Category chips — a thumb-height rail (44px minimum) linking to category
  pages. Food sells by kind: rice dishes, soups, drinks. Hidden entirely
  when the store has no categories.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "dede/categories"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <nav
      :if={@categories != []}
      class="px-4 pt-4 sm:px-6 sm:pt-6 lg:px-8"
      aria-label="Product categories"
    >
      <div class="mx-auto flex max-w-[880px] gap-2.5 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
        <a
          :for={category <- @categories}
          href={store_path(@store.slug, "/category/#{category.slug}")}
          class="inline-flex min-h-11 flex-shrink-0 items-center whitespace-nowrap rounded-full border-2 border-[#26211A]/20 bg-white px-5 text-sm font-semibold text-[#26211A] hover:border-[#26211A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-colors"
        >
          {category.name}
        </a>
      </div>
    </nav>
    """
  end
end
