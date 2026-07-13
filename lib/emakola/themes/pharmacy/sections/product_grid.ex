defmodule Emakola.Themes.Pharmacy.Sections.ProductGrid do
  @moduledoc """
  Pharmacy home product grid — the products the trending strip did not take
  (up to twelve more). Extracted verbatim from `pharmacy/home.ex`.

  Shares the legacy `@theme.sections.featured_products` toggle with the
  trending strip, exactly as before.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/product_grid"

  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :grid_products, Enum.drop(Map.get(assigns, :products) || [], 4))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :featured_products) && @grid_products != []}
      class="bg-[#F9F6F0] pb-14 sm:pb-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5">
          <Shared.product_card
            :for={product <- Enum.take(@grid_products, 12)}
            product={product}
            store={@store}
          />
        </div>
      </div>
    </section>
    """
  end
end
