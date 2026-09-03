defmodule Emakola.Themes.Sika.Home do
  @moduledoc """
  Sika theme — home page chrome.

  Renders theme chrome only — skip link, Sika's banner nav (maker's-mark
  wordmark, categories, search, live cart count), the store's effective
  home-section layout via `SectionRenderer`, the velvet footer, and the
  mobile tab bar. Section markup lives in `Emakola.Themes.Sika.Sections.*`.
  """
  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer
  alias Emakola.Themes.Sika.Shared

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Sika)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="bg-[#FAF9F7] text-[#211D16] [font-family:var(--dt-body-font,Work_Sans,system-ui,sans-serif)]">
      <Shared.theme_styles theme={@theme} />
      <a
        href="#sika-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:bg-[#211D16] focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>
      <Shared.sika_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div id="sika-content">
        {SectionRenderer.home(assigns)}
      </div>
      <div class="h-16 sm:hidden" aria-hidden="true"></div>
    </div>

    <Shared.footer store={@store} categories={@categories} />
    <Shared.sika_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} />
    """
  end
end
