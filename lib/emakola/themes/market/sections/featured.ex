defmodule Emakola.Themes.Market.Sections.Featured do
  @moduledoc """
  Market home featured product — one large "stall front" card for the most
  recent active product: photo (placeholder-first), oversized price chip,
  name, primary CTA.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Market.Components

  @impl true
  def key, do: "market/featured"
  @impl true
  def label, do: "Featured product"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@products != []}
      class="px-4 py-4 sm:px-6 sm:py-5 lg:px-8"
      aria-label="Featured product"
    >
      <div class="mx-auto max-w-[1280px]">
        <Components.featured_card product={List.first(@products)} store={@store} />
      </div>
    </section>
    """
  end
end
