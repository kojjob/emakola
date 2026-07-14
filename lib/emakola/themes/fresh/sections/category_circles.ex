defmodule Emakola.Themes.Fresh.Sections.CategoryCircles do
  @moduledoc """
  Fresh home category circles — farmers-market signboards in a horizontal
  scroller.

  They are links to each category's own page. They used to be buttons firing
  `filter_category` at `StoreLive`, which handles no such event: every tap raised
  FunctionClauseError, killed the LiveView and reset the page under the shopper.
  There is no product list on the home page to filter in the first place.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

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
          <%!-- Links, not filter buttons. These fired `filter_category` at
               StoreLive, which has no such handler — every category on the Fresh
               home page raised FunctionClauseError and took the page down. --%>
          <Shared.category_circle
            :for={category <- @categories}
            category={category}
            href={store_path(@store.slug, "/category/#{category.slug}")}
          />
        </div>
      </div>
    </section>
    """
  end
end
