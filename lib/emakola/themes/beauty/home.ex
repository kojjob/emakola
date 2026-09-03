defmodule Emakola.Themes.Beauty.Home do
  @moduledoc """
  Beauty theme — home page chrome.

  Renders the warm botanical body wrapper, the theme's CSS custom properties,
  the store's effective home-section layout via `SectionRenderer`, and the
  deep-walnut footer. Section markup lives in
  `Emakola.Themes.Beauty.Sections.*`; each section is a top-level sibling
  owning its own max-width container and horizontal padding.

  Beauty's nav is part of the hero band (it sits on the walnut, `on_dark`),
  so it is rendered by `Sections.Hero` rather than here — moving it out would
  change the storefront's rendered output.
  """

  use Phoenix.Component

  alias Emakola.Themes.Beauty.Shared
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
      |> assign(:theme_module, Emakola.Themes.Beauty)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="beauty-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      {SectionRenderer.home(assigns)}

      <Shared.beauty_footer store={@store} />
    </div>
    """
  end
end
