defmodule Emakola.Themes.Akwaaba.Home do
  @moduledoc """
  Akwaaba home — chrome plus the section layout.

  The nav is rendered in **overlay** mode and the whole page is wrapped in a
  positioning context, so the pill bar floats inside the hero's orange panel the
  way a sign sits on an awning. The hero reserves top padding for it.
  """
  use Phoenix.Component

  alias Emakola.Themes.Akwaaba.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Akwaaba)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="bg-white">
      <Shared.theme_styles theme={@theme} />
      <a
        href="#akwaaba-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-[color:var(--akwaaba-ink)] focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>

      <div class="relative">
        <Shared.akwaaba_nav
          store={@store}
          categories={@categories}
          cart_count={assigns[:cart_count] || 0}
          overlay
        />
        <div id="akwaaba-content">
          {SectionRenderer.home(assigns)}
        </div>
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} active={:home} />
    """
  end
end
