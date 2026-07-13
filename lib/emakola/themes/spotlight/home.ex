defmodule Emakola.Themes.Spotlight.Home do
  @moduledoc """
  Spotlight theme — home page chrome.

  Renders theme chrome only — the `spot-body` shell, theme styles, nav and
  footer — plus the store's effective home-section layout via
  `SectionRenderer`. Section markup lives in
  `Emakola.Themes.Spotlight.Sections.*`; each section is a top-level sibling
  owning its own horizontal padding (Spotlight's blocks always did, so the
  shell adds none).
  """

  use Phoenix.Component

  alias Emakola.Themes.SectionRenderer
  alias Emakola.Themes.Spotlight.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Spotlight)

    ~H"""
    <div class="spot-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.nav store={@store} cart_count={@cart_count} />

      {SectionRenderer.home(assigns)}

      <Shared.footer store={@store} />
    </div>
    """
  end
end
