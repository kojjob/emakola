defmodule Emakola.Themes.Vibrant.Home do
  @moduledoc """
  Vibrant theme — home page chrome.

  Renders theme chrome only: the CSS custom-property block, Vibrant's own
  sticky nav, the store's effective home-section layout via `SectionRenderer`,
  and the borrowed Atelier footer. Every block that used to live here — hero,
  trust badges, editor's picks, occasion edits, featured card, product grid,
  artisan signature, newsletter, service strip — now lives in
  `Emakola.Themes.Vibrant.Sections.*` as a top-level sibling owning its own
  max-width container and horizontal padding, plus the pattern divider that
  precedes it.
  """
  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer
  alias Emakola.Themes.Vibrant.Shared

  @doc """
  Renders the Vibrant theme home page.

  Expects assigns:
  - `@store` — store map with `.name`, `.slug`, `.description`, `.whatsapp_number`,
    optionally `.city`, `.region`, `.logo_url`
  - `@products` — list of products with `.title`, `.slug`, `.min_price`, `.max_price`, `.images`
  - `@categories` — list of root categories with `.name`, `.slug`, optionally `.image_url`
  - `@theme` — theme config map with `.sections` booleans and optional `.hero` overrides
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Vibrant)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="min-h-screen bg-[#FFFBEB]">
      <Shared.theme_styles theme={@theme} />
      <Shared.vibrant_nav store={@store} cart_count={assigns[:cart_count] || 0} />

      {SectionRenderer.home(assigns)}

      <%!-- The borrowed footer carries its own capture form; like the
           newsletter section it waits for a full stall. --%>
      <Emakola.Themes.Atelier.Shared.footer
        store={@store}
        categories={@categories}
        hide_newsletter={!@layout.show_newsletter?}
      />
    </div>
    """
  end
end
