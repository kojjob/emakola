defmodule Emakola.Themes.Vibrant.Sections.EditorsPicks do
  @moduledoc """
  Vibrant editor's picks — the 2-up flagship pair, shown only when the shop has
  at least two products (a single card in a two-column grid reads as a bug).

  Gated by the theme's `featured` toggle, like the featured card below it.

  The `<h2>` copy stays in the markup rather than becoming a setting: it carries
  an apostrophe, and routing it through an interpolation would HTML-escape it —
  a byte-level change to every existing storefront for no merchant benefit.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Vibrant.Shared
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def key, do: "vibrant/editors_picks"

  @impl true
  def label, do: "Featured"

  @impl true
  def settings_schema do
    [%{key: "eyebrow", type: :string, label: "Eyebrow", default: ""}]
  end

  @impl true
  def render(assigns) do
    products = Map.get(assigns, :products) || []
    settings = assigns[:settings] || %{}

    assigns =
      assigns
      |> assign(:products, products)
      |> assign(
        :enabled,
        Shared.section_enabled?(assigns.theme, :featured) and length(products) >= 2
      )
      # Blanking the schema default is not enough: this `||` would put "This
      # Week" straight back. There is no weekly cycle and nobody picked these —
      # they are the first two products. No eyebrow unless the merchant writes one.
      |> assign(:eyebrow, present(settings["eyebrow"]))

    ~H"""
    <section
      :if={@enabled}
      class="py-10 sm:py-14 bg-[#FFFBEB]"
      aria-labelledby="vibrant-editors-picks"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-6 sm:mb-8">
          <p
            :if={@eyebrow}
            class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#B45309)] mb-2"
          >
            {@eyebrow}
          </p>
          <h2
            id="vibrant-editors-picks"
            class="text-2xl sm:text-3xl font-bold text-[#1C1917]"
            style="font-family: 'Manrope', sans-serif;"
          >
            Featured
          </h2>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-5 sm:gap-6">
          <.editor_pick_card
            product={Enum.at(@products, 0)}
            store={@store}
            bg="#FEF3C7"
            text_color="#92400E"
          />
          <.editor_pick_card
            product={Enum.at(@products, 1)}
            store={@store}
            bg="#FEEFE0"
            text_color="#9A3412"
          />
        </div>
      </div>
    </section>
    """
  end

  # ── Editor Pick Card (private) ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :bg, :string, required: true
  attr :text_color, :string, required: true

  defp editor_pick_card(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={store_path(@store.slug, "/products/#{@product.slug}")}
      class="group flex flex-col sm:flex-row gap-5 rounded-3xl overflow-hidden p-5 sm:p-6 transition-all duration-300 hover:shadow-xl hover:shadow-amber-200/40"
      style={"background-color: #{@bg};"}
      aria-label={"Featured: #{@product.title}"}
    >
      <div class="flex-1 min-w-0 flex flex-col justify-center order-2 sm:order-1">
        <span
          class="text-[10px] font-bold tracking-[0.2em] uppercase mb-2"
          style={"color: #{@text_color};"}
        >
          Featured
        </span>
        <h3
          class="text-xl sm:text-2xl font-bold text-[#1C1917] leading-tight mb-2"
          style="font-family: 'Manrope', sans-serif;"
        >
          {@product.title}
        </h3>
        <p
          :if={@product.description}
          class="text-sm text-[#57534E] leading-relaxed mb-4 line-clamp-2"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p class="text-lg font-bold tabular-nums mb-4" style={"color: #{@text_color};"}>
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span class="inline-flex items-center gap-1 text-sm font-semibold text-[#1C1917] group-hover:gap-2 transition-all">
          Shop now <span class="material-symbols-outlined text-base">arrow_forward</span>
        </span>
      </div>
      <div class="flex-shrink-0 w-full sm:w-40 lg:w-48 aspect-square rounded-2xl overflow-hidden bg-white/40 order-1 sm:order-2">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-4xl" style={"color: #{@text_color};"}>
            shopping_bag
          </span>
        </div>
      </div>
    </a>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
