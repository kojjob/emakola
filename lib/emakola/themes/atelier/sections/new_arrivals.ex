defmodule Emakola.Themes.Atelier.Sections.NewArrivals do
  @moduledoc "Atelier home new arrivals / trending grid -- extracted verbatim from atelier/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Atelier.Shared

  @impl true
  def key, do: "atelier/new_arrivals"
  @impl true
  def label, do: "New Arrivals"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    # Show products not in the featured hero section (skip first product used as hero)
    featured_count = min(length(assigns.products), 5)
    trending = assigns.products |> Enum.drop(featured_count) |> Enum.take(4)
    # If not enough overflow, show last 4 products in different order
    trending =
      if trending == [], do: assigns.products |> Enum.reverse() |> Enum.take(4), else: trending

    assigns = assign(assigns, :trending, trending)

    ~H"""
    <section
      :if={
        Shared.section_enabled?(@theme, :featured_products) and length(@products) > 3 and
          @trending != []
      }
      class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24"
    >
      <div class="flex items-center justify-between mb-8">
        <h2 class="font-serif text-2xl sm:text-3xl font-semibold text-cta-dark">
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "New Arrivals"}
        </h2>
        <a
          href={store_path(@store.slug, "/products")}
          class="group inline-flex items-center gap-1.5 text-sm font-semibold transition-colors hover:opacity-80"
          style="color: var(--theme-primary);"
        >
          View all
          <svg
            class="w-4 h-4 transition-transform group-hover:translate-x-0.5"
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
        </a>
      </div>
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
        <Shared.product_card :for={product <- @trending} product={product} store={@store} />
      </div>
    </section>
    """
  end
end
