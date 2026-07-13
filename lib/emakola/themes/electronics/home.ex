defmodule Emakola.Themes.Electronics.Home do
  @moduledoc """
  Electronics theme home — page chrome.

  Renders the theme's own chrome (style block, cream body, midnight footer)
  and the store's effective home-section layout via `SectionRenderer`.
  Section markup lives in `Emakola.Themes.Electronics.Sections.*`; each
  section is a top-level sibling owning its own max-width container and
  horizontal padding.

  The teal nav belongs to the hero section, not to this module: it is drawn
  translucent against the hero's teal band and only reads as a header there.
  """

  use Phoenix.Component

  alias Emakola.Themes.Electronics.Shared
  alias Emakola.Themes.SectionRenderer

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Electronics)

    ~H"""
    <div class="electronics-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      {SectionRenderer.home(assigns)}

      <Shared.electronics_footer store={@store} />
    </div>
    """
  end
end
