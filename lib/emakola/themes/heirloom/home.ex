defmodule Emakola.Themes.Heirloom.Home do
  @moduledoc """
  Heirloom home — chrome only.

  Skip link, nav, the store's effective section layout via `SectionRenderer`,
  then the footer. Section markup lives in
  `Emakola.Themes.Heirloom.Sections.*`.

  The nav is chrome rather than part of the hero section deliberately. Themes
  that put their nav inside a section (Fashion, Beauty, Electronics,
  HomeLiving) lose their navigation entirely if that section is disabled or
  the theme is missing from the `Sections` registry. Here it cannot happen.
  """
  use Phoenix.Component

  alias Emakola.Themes.Heirloom.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Heirloom)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="bg-[color:var(--hl-bg)] [font-family:var(--hl-font)]">
      <Shared.theme_styles theme={@theme} />
      <a
        href="#heirloom-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-[color:var(--hl-ink)] focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>
      <Shared.heirloom_nav store={@store} cart_count={assigns[:cart_count] || 0} on_dark={true} />
      <div id="heirloom-content">
        {SectionRenderer.home(assigns)}
      </div>
    </div>

    <%!-- The footer's capture form waits for a full stall, like every
         newsletter on the platform (Emakola.Themes.Layout). --%>
    <Shared.footer
      store={@store}
      categories={assigns[:categories] || []}
      hide_newsletter={!@layout.show_newsletter?}
    />
    """
  end
end
