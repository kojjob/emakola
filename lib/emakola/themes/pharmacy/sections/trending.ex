defmodule Emakola.Themes.Pharmacy.Sections.Trending do
  @moduledoc """
  Pharmacy home "From our shelves" strip — the featured product and up to
  three more, on the cream band. The highlight cards and the grid take what
  is left, so no product is shown twice on the home.

  Still gated by the legacy `@theme.sections.featured_products` toggle it
  shared with the product grid, so a merchant who switched featured products
  off the old way keeps both blocks off.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/trending"

  @impl true
  def label, do: "Featured products"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    layout = Layout.of(assigns)

    shelf =
      if layout.featured,
        do: [layout.featured | Enum.take(layout.grid_products, 3)],
        else: []

    assigns = assign(assigns, :featured_products, shelf)

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :featured_products) && @featured_products != []}
      class="bg-[#F9F6F0] pb-14 sm:pb-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-8">
          <div>
            <%!-- A hardcoded "Trending now" eyebrow sat here — not even a
                 setting — above the first four products in catalog order. There
                 is no trend, and on a pharmacy a fake popularity signal on
                 medicine is worse than merchandising puff. --%>
            <h2 class="pharmacy-heading text-3xl sm:text-4xl font-medium text-[#14543E]">
              {if @settings["heading"] not in [nil, ""],
                do: @settings["heading"],
                else: "From our shelves"}
            </h2>
          </div>
          <a
            href={store_path(@store.slug, "/products")}
            class="hidden sm:inline-flex items-center gap-1 text-sm font-semibold text-[#14543E] hover:gap-2 transition-all"
          >
            See all
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>

        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5">
          <Shared.product_card :for={product <- @featured_products} product={product} store={@store} />
        </div>
      </div>
    </section>
    """
  end
end
