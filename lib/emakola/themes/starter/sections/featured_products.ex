defmodule Emakola.Themes.Starter.Sections.FeaturedProducts do
  @moduledoc "Starter home featured products grid -- extracted verbatim from starter/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import Emakola.Themes.Starter.Sections.Helpers

  alias Emakola.Themes.Starter.Shared

  @impl true
  def key, do: "starter/featured_products"
  @impl true
  def label, do: "Featured Products"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={section_enabled?(@theme, :featured) and @products != []}
      class="py-10 bg-white"
      aria-labelledby="starter-featured"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between mb-6">
          <h2
            id="starter-featured"
            class="text-2xl font-semibold text-[#0F172A]"
            style="font-family: 'Inter', sans-serif;"
          >
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: "Featured Products"}
          </h2>
          <a
            href={store_path(@store.slug, "/products")}
            class="text-sm font-medium text-[var(--theme-primary,#6366F1)] hover:text-[#4F46E5] transition-colors flex items-center gap-1"
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
          <Shared.product_card :for={product <- @products} product={product} store={@store} />
        </div>
      </div>
    </section>
    """
  end
end
