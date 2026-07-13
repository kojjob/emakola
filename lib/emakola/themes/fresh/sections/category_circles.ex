defmodule Emakola.Themes.Fresh.Sections.CategoryCircles do
  @moduledoc """
  Fresh home category circles — farmers-market signboards in a horizontal
  scroller. Extracted verbatim from `fresh/home.ex`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Fresh.Shared

  @impl true
  def key, do: "fresh/category_circles"
  @impl true
  def label, do: "Category Circles"

  # No settings: the heading is static template text, kept verbatim so the
  # storefront's output is unchanged.
  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :categories) and @categories != []}
      class="py-6 bg-[#FEFCE8]"
      aria-label="Product categories"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <h2
          class="text-lg font-bold text-cta-dark mb-4"
          style="font-family: 'Nunito', sans-serif;"
        >
          Shop by Category
        </h2>
        <div
          class="flex gap-5 overflow-x-auto pb-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
          role="list"
        >
          <Shared.category_circle
            :for={category <- @categories}
            category={category}
            store_slug={@store.slug}
          />
        </div>
      </div>
    </section>
    """
  end
end
