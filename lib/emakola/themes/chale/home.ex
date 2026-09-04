defmodule Emakola.Themes.Chale.Home do
  @moduledoc """
  Chale theme — home page chrome.

  Renders theme chrome only — skip link, Chale's own banner nav (store
  identity, categories, search, live cart count), the store's effective
  home-section layout via `SectionRenderer`, Chale's own footer, and the
  mobile bottom tab bar. Section markup lives in
  `Emakola.Themes.Chale.Sections.*`; each section is a top-level sibling
  owning its own horizontal padding.
  """
  use Phoenix.Component

  alias Emakola.Themes.Chale.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Chale)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div>
      <Shared.theme_styles theme={@theme} />
      <a
        href="#chale-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:bg-[#101114] focus:px-5 focus:py-3 focus:text-sm focus:font-bold focus:uppercase focus:tracking-widest focus:text-white"
      >
        Skip to content
      </a>
      <Shared.chale_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div id="chale-content">
        {SectionRenderer.home(assigns)}
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.chale_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} active={:home} />
    """
  end
end
