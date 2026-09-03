defmodule Emakola.Themes.HomeLiving.Home do
  @moduledoc """
  Home Living theme — home page chrome.

  Renders theme chrome only — the `home-living-body` shell, the theme styles
  and the charcoal footer — plus the store's effective home-section layout via
  `SectionRenderer`. Section markup lives in
  `Emakola.Themes.HomeLiving.Sections.*`; each section is a top-level sibling
  owning its own max-width and horizontal padding (Home Living's blocks always
  did, so the shell adds none).

  The nav is NOT chrome here: it has always rendered inside the hero section,
  as a transparent `on_dark` header laid over the hero's own photographic
  background. Lifting it out would visibly change every live storefront, so it
  stays in `Sections.Hero` — see that module.
  """

  use Phoenix.Component

  alias Emakola.Themes.HomeLiving.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.HomeLiving)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="home-living-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      {SectionRenderer.home(assigns)}

      <Shared.home_living_footer store={@store} categories={@categories} />
    </div>
    """
  end
end
