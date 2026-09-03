defmodule Emakola.Themes.Fashion.Sections.FeaturedProducts do
  @moduledoc """
  Fashion home featured-products grid — extracted verbatim from fashion/home.ex.

  Shows the catalogue after the lookbook's four, so nothing on the page
  appears twice; with four products or fewer the lookbook carries them all
  and this grid stays off the page.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Fashion.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "fashion/featured_products"

  @impl true
  def label, do: "Featured products"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :featured_products, Shared.edit_products(Layout.of(assigns)))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :featured_products) && @featured_products != []}
      class="bg-[#FAF6EE] pb-14 sm:pb-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-8">
          <div>
            <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-2">
              The Edit
            </p>
            <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-[#1C1917]">
              Just dropped.
            </h2>
          </div>
        </div>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
          <Shared.product_card :for={product <- @featured_products} product={product} store={@store} />
        </div>
      </div>
    </section>
    """
  end
end
