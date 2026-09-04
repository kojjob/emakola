defmodule Emakola.Themes.Fashion.Home do
  @moduledoc """
  Fashion theme home — editorial magazine.

  Renders theme chrome — the `fashion-body` type/colour ground, the theme's
  `<style>` block and the aubergine masthead footer — around the store's
  effective home-section layout, rendered by `SectionRenderer`. Section markup
  lives in `Emakola.Themes.Fashion.Sections.*`; each section is a top-level
  sibling owning its own background and horizontal padding.

  Fashion's nav is part of the hero's markup (a transparent header the cover
  image is pulled up under), so it lives in `Sections.Hero` rather than here —
  see that module.
  """

  use Phoenix.Component

  alias Emakola.Themes.Fashion.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Fashion)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="fashion-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      {SectionRenderer.home(assigns)}

      <Shared.fashion_footer store={@store} />
    </div>
    """
  end
end
