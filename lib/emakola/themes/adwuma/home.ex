defmodule Emakola.Themes.Adwuma.Home do
  @moduledoc """
  Adwuma home — chrome only. The bands themselves come from `SectionRenderer`,
  so a merchant can reorder or disable any of them.

  Nav and footer live **here**, not inside the hero section. A merchant who
  disables or reorders their hero must never lose the shop's navigation with
  it — the failure mode several earlier themes shipped with.
  """
  use Phoenix.Component

  alias Emakola.Themes.Adwuma.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    # Required: the layout's fallback header renders when :theme_module is
    # absent, and SectionRenderer resolves this theme's sections through it.
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Adwuma)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="min-h-screen bg-[color:var(--adw-bg)] pb-16 text-[color:var(--adw-ink)] sm:pb-0">
      <Shared.theme_styles theme={@theme} />

      <a
        href="#adwuma-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-full focus:bg-[color:var(--adw-ink)] focus:px-5 focus:py-2 focus:text-sm focus:text-white"
      >
        Skip to content
      </a>

      <Shared.adwuma_nav
        store={@store}
        categories={Map.get(assigns, :categories) || []}
        cart_count={Map.get(assigns, :cart_count) || 0}
      />

      <main id="adwuma-content">
        {SectionRenderer.home(assigns)}
      </main>

      <Shared.footer store={@store} categories={Map.get(assigns, :categories) || []} />
      <Shared.bottom_nav store={@store} cart_count={Map.get(assigns, :cart_count) || 0} />
    </div>
    """
  end
end
