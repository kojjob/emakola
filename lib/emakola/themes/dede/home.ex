defmodule Emakola.Themes.Dede.Home do
  @moduledoc """
  Dede theme — home page chrome.

  Renders theme chrome only: skip link, Dede's own banner nav (store
  identity, categories, search, WhatsApp, live cart count), the store's
  effective home-section layout via `SectionRenderer`, Dede's board
  footer, and the mobile tab bar. Section markup lives in
  `Emakola.Themes.Dede.Sections.*`.
  """
  use Phoenix.Component

  alias Emakola.Themes.Dede.Shared
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Dede)

    ~H"""
    <div class="min-h-screen bg-[#FAF5EA]">
      <Shared.theme_styles theme={@theme} />
      <a
        href="#dede-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-[#1B2E23] focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-[#F3EDDF]"
      >
        Skip to content
      </a>
      <Shared.dede_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div id="dede-content">
        {SectionRenderer.home(assigns)}
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} />
    <Shared.dede_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} />
    """
  end
end
