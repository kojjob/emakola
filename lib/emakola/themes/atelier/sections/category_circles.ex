defmodule Emakola.Themes.Atelier.Sections.CategoryCircles do
  @moduledoc "Atelier home category circles -- extracted verbatim from atelier/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Atelier.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "atelier/category_circles"
  @impl true
  def label, do: "Category Circles"

  @impl true
  def settings_schema, do: []

  @category_colors [
    {"from-[#B45309]/10 to-[#92400E]/5", "bg-store-accent"},
    {"from-[#7C3AED]/10 to-[#6D28D9]/5", "bg-[#7C3AED]"},
    {"from-[#059669]/10 to-[#047857]/5", "bg-[#059669]"},
    {"from-[#DC2626]/10 to-[#B91C1C]/5", "bg-[#DC2626]"},
    {"from-[#2563EB]/10 to-[#1D4ED8]/5", "bg-[#2563EB]"}
  ]

  @impl true
  def render(assigns) do
    categories_with_colors =
      assigns.categories
      |> Enum.with_index()
      |> Enum.map(fn {cat, idx} ->
        {grad, dot_color} = Enum.at(@category_colors, rem(idx, length(@category_colors)))

        %{category: cat, gradient: grad, dot_color: dot_color}
      end)

    assigns =
      assigns
      |> assign(:categories_with_colors, categories_with_colors)
      |> assign(:layout, Layout.of(assigns))

    ~H"""
    <section
      :if={
        Shared.section_enabled?(@theme, :categories) and @categories != [] and
          @layout.show_categories?
      }
      class="py-10 sm:py-14"
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between mb-6 sm:mb-8">
          <h2 class="font-serif text-xl sm:text-2xl font-semibold text-cta-dark">
            Shop by Category
          </h2>
          <a
            href={store_path(@store.slug, "/products")}
            class="text-xs sm:text-sm font-medium text-[#78716C] hover:text-cta-dark transition-colors"
          >
            Browse all
          </a>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
          <a
            :for={item <- @categories_with_colors}
            href={store_path(@store.slug, "/category/#{item.category.slug}")}
            class={"group relative overflow-hidden rounded-2xl bg-gradient-to-br #{item.gradient} border border-[#E7E5E4] p-6 sm:p-8 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300 cursor-pointer"}
          >
            <%!-- Decorative accent --%>
            <div class={"absolute top-0 right-0 w-24 h-24 rounded-full #{item.dot_color} opacity-[0.04] -translate-y-8 translate-x-8 group-hover:opacity-[0.08] transition-opacity"}>
            </div>

            <%!-- A plain tile: the initial that used to sit here in a badge
                 is nothing to a buyer who reads slowly. --%>
            <%!-- Category name --%>
            <h3 class="text-base sm:text-lg font-semibold text-cta-dark mb-1">
              {item.category.name}
            </h3>

            <%!-- Arrow indicator --%>
            <div class="flex items-center gap-1 mt-2">
              <span class="text-xs font-medium text-[#78716C] group-hover:text-cta-dark transition-colors">
                Explore
              </span>
              <svg
                class="w-3.5 h-3.5 text-[#78716C] group-hover:text-cta-dark group-hover:translate-x-0.5 transition-all"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </div>
          </a>
        </div>
      </div>
    </section>
    """
  end
end
