defmodule Emakola.Themes.Fresh.Sections.Featured do
  @moduledoc """
  Fresh home "Today's Picks" — the first four products of the catalogue.
  Extracted verbatim from `fresh/home.ex`, which derived the same slice with
  `Enum.take(products, 4)`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fresh.Shared

  @impl true
  def key, do: "fresh/featured"
  @impl true
  def label, do: "Today's Picks"

  # No settings: the heading is static template text. Interpolating it would
  # HTML-escape the apostrophe (`Today&#39;s Picks`) and change the storefront's
  # output — the retrofit's one hard rule.
  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :featured_products, fn -> Enum.take(assigns.products, 4) end)

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :featured) and @featured_products != []}
      class="py-8 bg-[#FEFCE8]"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-2.5">
            <span
              class="material-symbols-outlined text-[#059669]"
              style="font-size: 24px;"
            >
              local_fire_department
            </span>
            <h2
              class="text-2xl font-bold text-cta-dark"
              style="font-family: 'Nunito', sans-serif;"
            >
              Today's Picks
            </h2>
          </div>
          <a
            href={store_path(@store.slug, "/products")}
            class="text-sm font-semibold text-[#059669] hover:text-[#047857] transition-colors flex items-center gap-1"
            style="font-family: 'Inter', sans-serif;"
          >
            View All
            <svg
              class="w-4 h-4"
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
        <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
          <Shared.product_card
            :for={product <- @featured_products}
            product={product}
            store={@store}
          />
        </div>
      </div>
    </section>
    """
  end
end
