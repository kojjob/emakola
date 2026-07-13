defmodule Emakola.Themes.Vibrant.Sections.ProductGrid do
  @moduledoc """
  Vibrant product grid — the mobile-first 2/3/4-column shop-all grid.

  Carries the ankara pattern divider that has always preceded it; like the
  featured card's kente rule, the divider sits outside the section's gate so a
  store that hid the grid keeps the rhythm it has today.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [pattern_divider: 1]

  alias Emakola.Themes.Vibrant.Shared

  @impl true
  def key, do: "vibrant/product_grid"

  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema do
    [
      %{key: "eyebrow", type: :string, label: "Eyebrow", default: "Just Landed"},
      %{key: "heading", type: :string, label: "Heading", default: "Picked for you"}
    ]
  end

  @impl true
  def render(assigns) do
    products = Map.get(assigns, :products) || []
    settings = assigns[:settings] || %{}

    assigns =
      assigns
      |> assign(:grid_products, products)
      |> assign(
        :enabled,
        Shared.section_enabled?(assigns.theme, :products) and products != []
      )
      |> assign(:eyebrow, present(settings["eyebrow"]) || "Just Landed")
      |> assign(:heading, present(settings["heading"]) || "Picked for you")

    ~H"""
    <.pattern_divider variant={:ankara} class="bg-[#FFFBEB]" />

    <section :if={@enabled} class="py-8 sm:py-12 bg-[#FFFBEB]" aria-labelledby="vibrant-shop-all">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-6 sm:mb-8">
          <div>
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#B45309)] mb-2">
              {@eyebrow}
            </p>
            <h2
              id="vibrant-shop-all"
              class="text-2xl sm:text-3xl font-bold text-[#1C1917]"
              style="font-family: 'Manrope', sans-serif;"
            >
              {@heading}
            </h2>
          </div>
          <a
            href={store_path(@store.slug, "/products")}
            class="text-sm font-semibold text-[var(--theme-primary,#B45309)] hover:text-[var(--theme-accent,#7C2D12)] transition-colors flex items-center gap-1"
          >
            View all
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
              />
            </svg>
          </a>
        </div>
        <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
          <Shared.product_card :for={product <- @grid_products} product={product} store={@store} />
        </div>
      </div>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
