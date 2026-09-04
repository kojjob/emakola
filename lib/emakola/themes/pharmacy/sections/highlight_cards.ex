defmodule Emakola.Themes.Pharmacy.Sections.HighlightCards do
  @moduledoc """
  Pharmacy home highlight cards — three pastel blocks showcasing the three
  products after the ones "From our shelves" took (the featured product plus
  three), so nothing on the home appears twice. Carries the card component
  and its pastel palette.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/highlight_cards"

  @impl true
  def label, do: "Highlight cards"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    highlights = Layout.of(assigns).grid_products |> Enum.drop(3) |> Enum.take(3)

    assigns = assign(assigns, :highlight_products, highlights)

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :highlight_cards) && @highlight_products != []}
      class="bg-[#F9F6F0] pb-14 sm:pb-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-5">
          <.highlight_card
            :for={{product, idx} <- Enum.with_index(@highlight_products)}
            product={product}
            store={@store}
            palette={highlight_palette(idx)}
          />
        </div>
      </div>
    </section>
    """
  end

  # ── Highlight feature card ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :palette, :map, required: true

  defp highlight_card(assigns) do
    ~H"""
    <a
      href={store_path(@store.slug, "/products/#{@product.slug}")}
      class="relative block rounded-2xl p-6 sm:p-8 overflow-hidden group"
      style={"background-color: #{@palette.bg};"}
    >
      <div class="relative z-10 max-w-[55%]">
        <h3 class="pharmacy-heading text-xl sm:text-2xl font-semibold text-[#1F2937] leading-tight mb-2">
          {@product.title}
        </h3>
        <p class="text-base font-bold text-[#14543E] mb-4">
          {EmakolaWeb.Helpers.Currency.format_price(
            @product.min_price || 0,
            Map.get(@store, :currency, "GHS")
          )}
        </p>
        <span class="inline-flex items-center gap-1.5 text-sm font-semibold text-[#14543E]">
          Shop now
          <span class="material-symbols-outlined" style="font-size: 16px;">arrow_forward</span>
        </span>
      </div>
      <%= if Shared.first_image(@product) do %>
        <img
          src={Shared.first_image(@product)}
          alt={@product.title}
          class="absolute right-2 sm:right-4 bottom-2 sm:bottom-4 w-32 h-32 sm:w-44 sm:h-44 object-cover group-hover:scale-105 transition-transform"
        />
      <% else %>
        <div
          class="absolute right-2 sm:right-4 bottom-2 sm:bottom-4 w-32 h-32 sm:w-44 sm:h-44 flex items-center justify-center"
          style={"color: #{@palette.icon};"}
          data-placeholder="product"
        >
          <span class="material-symbols-outlined" style="font-size: 100px;">medication</span>
        </div>
      <% end %>
    </a>
    """
  end

  defp highlight_palette(0), do: %{bg: "#E8F5EE", icon: "#14543E"}
  defp highlight_palette(1), do: %{bg: "#FFF4E6", icon: "#92400E"}
  defp highlight_palette(2), do: %{bg: "#E0EAFB", icon: "#1E3A8A"}
  defp highlight_palette(_), do: %{bg: "#F3F4F6", icon: "#6B7280"}
end
