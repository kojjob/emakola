defmodule Emakola.Themes.Pace.Sections.Featured do
  @moduledoc """
  Pace home front runner — one wide night-gradient card for the most
  recent active product: ghost initial or photo under the dark wash,
  oversized price pill, name, primary CTA. Renders nothing with zero
  products; the grid section owns the empty state.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Pace.Components

  @impl true
  def key, do: "pace/featured"
  @impl true
  def label, do: "Featured product"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@products != []}
      class="px-5 py-4 sm:px-8 sm:py-5 lg:px-10"
      aria-label="Featured product"
    >
      <div class="mx-auto max-w-[1280px]">
        <Components.featured_card product={List.first(@products)} store={@store} />
      </div>
    </section>
    """
  end
end
