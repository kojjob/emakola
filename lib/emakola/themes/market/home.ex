defmodule Emakola.Themes.Market.Home do
  @moduledoc """
  Market theme — home page chrome.

  Renders theme styles, the store's effective home-section layout via
  `SectionRenderer` (category strip, featured product, product grid, about),
  and the shared footer. Section markup lives in
  `Emakola.Themes.Market.Sections.*`; each section is a top-level sibling
  owning its own horizontal padding.
  """
  use Phoenix.Component

  alias Emakola.Themes.Market.Shared
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Market)

    ~H"""
    <div>
      <Shared.theme_styles theme={@theme} />
      {SectionRenderer.home(assigns)}
    </div>

    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    """
  end
end
