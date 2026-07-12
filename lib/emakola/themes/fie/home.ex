defmodule Emakola.Themes.Fie.Home do
  @moduledoc """
  Fie theme — home page chrome.

  Renders theme chrome only — skip link, Fie's own banner nav (store
  identity, collections, search, live cart count), the store's effective
  home-section layout via `SectionRenderer`, Fie's blush footer, and the
  mobile bottom tab bar. Section markup lives in
  `Emakola.Themes.Fie.Sections.*`; each section is a top-level sibling
  owning its own horizontal padding.
  """
  use Phoenix.Component

  alias Emakola.Themes.Fie.Shared
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Fie)

    ~H"""
    <div class="bg-[#FDFCFB]">
      <Shared.theme_styles theme={@theme} />
      <a
        href="#fie-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:bg-stone-900 focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>
      <Shared.fie_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div id="fie-content">
        {SectionRenderer.home(assigns)}
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.fie_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} active={:home} />
    """
  end
end
