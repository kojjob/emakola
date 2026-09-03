defmodule Emakola.Themes.Pharmacy.Home do
  @moduledoc """
  Pharmacy theme home page — premium wellness, trusted, accessibility-led.

  Renders theme chrome only — the cream body, the theme's CSS variables, the
  white sticky nav and the forest-green footer — and hands the page itself to
  `SectionRenderer`, which lays out the store's effective section layout.

  Section markup lives in `Emakola.Themes.Pharmacy.Sections.*`; each section
  is a top-level sibling owning its own `max-w-[1280px]` container and
  horizontal padding, exactly as the blocks did when they were inlined here.
  """

  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Pharmacy.Shared
  alias Emakola.Themes.SectionRenderer

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Pharmacy)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="pharmacy-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.pharmacy_nav store={@store} cart_count={@cart_count} />

      {SectionRenderer.home(assigns)}

      <Shared.pharmacy_footer store={@store} />
    </div>
    """
  end
end
