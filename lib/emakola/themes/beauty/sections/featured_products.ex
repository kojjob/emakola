defmodule Emakola.Themes.Beauty.Sections.FeaturedProducts do
  @moduledoc """
  Beauty featured-products grid — the first six active products in rounded,
  full-bleed cards, with a "see all" pill.

  The six-product slice used to be precomputed by `Beauty.Home`; each section
  now derives its own slice from `@products`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Beauty.Shared

  @limit 6

  @impl true
  def key, do: "beauty/featured_products"

  @impl true
  def label, do: "Featured products"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :featured_products, Enum.take(assigns.products, @limit))

    ~H"""
    <section
      :if={section_enabled?(@theme, :featured_products) && @featured_products != []}
      class="bg-[#F5EFE5] py-16 sm:py-24"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-12">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#8C5A24] mb-3">
            Our Products
          </p>
          <h2 class="beauty-heading text-4xl sm:text-5xl font-semibold text-[#3D2F25]">
            Curated for your routine
          </h2>
        </div>
        <div class={[
          "grid gap-4 sm:gap-6",
          if(length(@featured_products) == 1,
            do: "grid-cols-1 max-w-sm mx-auto",
            else: "grid-cols-2 lg:grid-cols-3"
          )
        ]}>
          <Shared.product_card :for={product <- @featured_products} product={product} store={@store} />
        </div>
        <div class="text-center mt-12">
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex items-center gap-2 px-7 py-3.5 rounded-full bg-[var(--theme-primary,#6B4423)] text-[#FAF6EE] text-sm font-semibold hover:bg-[#5A381D] transition-colors min-h-[48px]"
          >
            See all products
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>
      </div>
    </section>
    """
  end

  defp section_enabled?(theme, name) do
    case get_in(theme, [:sections, name]) do
      false -> false
      _ -> true
    end
  end
end
