defmodule Emakola.Themes.Bold.Home do
  @moduledoc """
  Bold theme — home page chrome.

  Renders theme chrome only — the CSS variable block, Bold's dark editorial
  nav, the store's effective home-section layout via `SectionRenderer`, and
  the dark editorial footer. Section markup lives in
  `Emakola.Themes.Bold.Sections.*`; each section is a top-level sibling
  owning its own max-width container and horizontal padding, exactly as it
  did when the blocks were nested here.
  """
  use Phoenix.Component

  alias Emakola.Themes.Bold.Shared
  alias Emakola.Themes.Layout
  alias Emakola.Themes.SectionRenderer

  @doc """
  Renders the Bold theme home page.

  Expects assigns:
  - `@store` — store map with `.name`, `.slug`, `.description`, `.whatsapp_number`
  - `@products` — list of products with `.title`, `.slug`, `.min_price`, `.max_price`, `.images`
  - `@categories` — list of categories with `.name`, `.slug`
  - `@theme` — theme config map with `.sections` booleans
  - `@cart_count` — integer cart item count
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Bold)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div class="min-h-screen bg-[#F8FAFC]">
      <Shared.theme_styles theme={@theme} />
      <Shared.bold_nav store={@store} cart_count={@cart_count} />

      {SectionRenderer.home(assigns)}

      <Shared.footer
        store={@store}
        categories={@categories}
        newsletter={@layout.show_newsletter?}
      />
    </div>
    """
  end
end
