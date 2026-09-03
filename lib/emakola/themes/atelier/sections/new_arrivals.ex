defmodule Emakola.Themes.Atelier.Sections.NewArrivals do
  @moduledoc "Atelier home new arrivals / trending grid -- extracted verbatim from atelier/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Atelier.Shared
  alias Emakola.Themes.Layout

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
    # Only what the featured bento (the featured product plus four) did not
    # take. There is no "show the last four again" fallback any more: the
    # same product in a different order is still the same product twice.
    trending = Layout.of(assigns).grid_products |> Enum.drop(4) |> Enum.take(4)

    assigns = assign(assigns, :trending, trending)

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :featured_products) and @trending != []}
      class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24"
    >
      <div class="flex items-center justify-between mb-8">
        <h2 class="font-serif text-2xl sm:text-3xl font-semibold text-cta-dark">
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "More from the shop"}
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
