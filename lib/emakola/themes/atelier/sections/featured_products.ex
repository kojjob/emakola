defmodule Emakola.Themes.Atelier.Sections.FeaturedProducts do
  @moduledoc "Atelier home featured products bento grid -- extracted verbatim from atelier/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Atelier.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "atelier/featured_products"
  @impl true
  def label, do: "Featured Products"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    # The bento takes the featured product and up to four more. Whatever is
    # left goes to "More from the shop", so no product appears twice.
    layout = Layout.of(assigns)

    assigns =
      assigns
      |> assign(:hero, layout.featured)
      |> assign(:grid_products, Enum.take(layout.grid_products, 4))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :featured_products) and @hero != nil}
      class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24"
    >
      <%!-- Section Header --%>
      <div class="flex items-center justify-between mb-8 sm:mb-10">
        <div>
          <h2 class="font-serif text-2xl sm:text-3xl font-semibold text-cta-dark">
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: "Featured Masterpieces"}
          </h2>
          <%!-- "Handpicked by our artisans" — the shop has artisans, and they
               chose these. Neither is something the platform knows; a store
               reselling phone cases said it too. --%>
          <p class="text-sm text-[#78716C] mt-1 hidden sm:block">From the collection</p>
        </div>
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

      <%!-- Bento Grid: Hero left + 2x2 right --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-5">
        <%!-- Hero Product --%>
        <div :if={@hero}>
          <Shared.hero_product_card product={@hero} store={@store} />
        </div>

        <%!-- Right: 2x2 grid --%>
        <div class="grid grid-cols-2 gap-3 sm:gap-4 h-full">
          <Shared.product_card
            :for={product <- @grid_products}
            product={product}
            store={@store}
          />
        </div>
      </div>

      <%!-- Extra products row --%>
    </section>
    """
  end
end
