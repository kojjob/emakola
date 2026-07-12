defmodule Emakola.Themes.Market.Sections.ProductGrid do
  @moduledoc """
  Market home "Shop All" grid — 2 / 3 / 4 columns. Cards carry the
  placeholder-first treatment, the price chip, and add-to-cart.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Market.Components

  @impl true
  def key, do: "market/product_grid"
  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Shop All"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@products != []}
      class="px-4 py-4 sm:px-6 sm:py-5 lg:px-8"
      aria-labelledby="shop-all-heading"
    >
      <div class="mx-auto max-w-[1280px]">
        <h2 id="shop-all-heading" class="mb-4 text-lg font-bold tracking-tight text-stone-900">
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Shop All"}
        </h2>
        <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 lg:grid-cols-4 lg:gap-5">
          <Components.product_card :for={product <- @products} product={product} store={@store} />
        </div>
      </div>
    </section>
    """
  end
end
