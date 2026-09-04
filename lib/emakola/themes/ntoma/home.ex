defmodule Emakola.Themes.Ntoma.Home do
  @moduledoc """
  Ntoma theme — home page chrome.

  Renders theme chrome only — skip link, Ntoma's own banner nav (serif
  wordmark, categories, search, live cart count), the store's effective
  home-section layout via `SectionRenderer`, Ntoma's own footer, and the
  mobile bottom tab bar. Section markup lives in
  `Emakola.Themes.Ntoma.Sections.*`; each section is a top-level sibling
  owning its own horizontal padding.
  """
  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Ntoma.Shared
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Ntoma)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="bg-[#FAF4EA]">
      <Shared.theme_styles theme={@theme} />
      <a
        href="#ntoma-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:bg-[#2B1708] focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-[#FAF4EA]"
      >
        Skip to content
      </a>
      <Shared.ntoma_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div id="ntoma-content">
        {SectionRenderer.home(assigns)}
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.ntoma_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} />
    """
  end
end
