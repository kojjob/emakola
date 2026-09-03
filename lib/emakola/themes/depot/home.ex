defmodule Emakola.Themes.Depot.Home do
  @moduledoc """
  Depot theme — home page chrome.

  Renders theme chrome only: skip link, Depot's own banner nav (store
  identity, category links, search, the live order count), the store's
  effective home-section layout via `SectionRenderer`, Depot's own footer,
  and the mobile tab bar. Section markup lives in
  `Emakola.Themes.Depot.Sections.*`; each section is a top-level sibling
  owning its own horizontal padding.
  """
  use Phoenix.Component

  alias Emakola.Themes.Depot.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Depot)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div>
      <Shared.theme_styles theme={@theme} />
      <a
        href="#depot-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:bg-zinc-900 focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>
      <Shared.depot_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div id="depot-content">
        {SectionRenderer.home(assigns)}
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.depot_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} active={:home} />
    """
  end
end
