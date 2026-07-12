defmodule Emakola.Themes.Pace.Home do
  @moduledoc """
  Pace theme — home page chrome.

  Renders theme chrome only — skip link, Pace's floating pill nav, the
  rounded canvas holding the store's effective home-section layout via
  `SectionRenderer`, the night-slab footer, and the mobile bottom pill.
  Section markup lives in `Emakola.Themes.Pace.Sections.*`; each section
  is a top-level sibling owning its own horizontal padding.
  """
  use Phoenix.Component

  alias Emakola.Themes.Pace.Shared
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Pace)

    ~H"""
    <div class="bg-[var(--theme-bg,#E6EFF6)] pt-2">
      <Shared.theme_styles theme={@theme} />
      <a
        href="#pace-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-slate-950 focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>
      <Shared.pace_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div class="px-2 pt-3 sm:px-4 lg:px-6">
        <div
          id="pace-content"
          class="mx-auto max-w-[1440px] rounded-[28px] bg-white pb-2 sm:rounded-[36px]"
        >
          {SectionRenderer.home(assigns)}
        </div>
      </div>
      <Shared.footer store={@store} categories={@categories} theme={@theme} />
    </div>
    <Shared.pace_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} />
    """
  end
end
