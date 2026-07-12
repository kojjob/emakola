defmodule Emakola.Themes.Market.Home do
  @moduledoc """
  Market theme — home page chrome.

  Renders theme chrome — skip link, Market's own banner nav (store
  identity, categories, search, live cart count), the store's effective
  home-section layout via `SectionRenderer`, Market's own footer, and the
  mobile bottom tab bar. Section markup lives in
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
      <a
        href="#market-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-stone-900 focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>
      <Shared.market_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div id="market-content">
        {SectionRenderer.home(assigns)}
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.market_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} />
    """
  end
end
