defmodule Emakola.Themes.HomeLiving.Sections.Hero do
  @moduledoc """
  Home Living home hero — extracted verbatim from home_living/home.ex.

  The dark charcoal, photographic signboard: bold uppercase headline, lime
  CTA, and two floating product tiles overlaid bottom-right. It carries the
  page's single `<h1>`.

  It also carries the theme's nav. That is where the nav has always lived —
  the header is a transparent, `on_dark` overlay laid over the hero's own
  photographic background, inside its `relative overflow-hidden` box — so
  moving it out into the page chrome would visibly change every Home Living
  storefront. It stays here, verbatim. Consequence, unchanged from before
  the retrofit: a store that turns the hero off has no nav on its home page.

  Settings are additive — a blank default falls back to the theme-config
  expression the block used before the retrofit, so an untouched storefront
  renders byte-identically.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.HomeLiving.Shared

  @impl true
  def key, do: "home_living/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""},
      %{key: "image_url", type: :image_url, label: "Background image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    hero = get_in(assigns.theme, [:hero]) || %{}
    products = Map.get(assigns, :products) || []

    assigns =
      assigns
      |> assign(:cart_count, Map.get(assigns, :cart_count) || 0)
      |> assign(:tile_products, Enum.take(products, 2))
      |> assign(
        :hero_image_url,
        present(assigns.settings["image_url"]) || theme_hero_image_url(assigns.theme)
      )
      |> assign(
        :headline,
        present(assigns.settings["headline"]) || Map.get(hero, :title) ||
          "Masterpieces Crafted From Solid Wood"
      )
      |> assign(
        :subheadline,
        present(assigns.settings["subheadline"]) || Map.get(hero, :subtitle)
      )
      |> assign(
        :cta_label,
        present(assigns.settings["cta_label"]) || Map.get(hero, :cta_text) || "Explore More"
      )

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :hero)}
      class="relative bg-[#1F2937] overflow-hidden"
    >
      <Shared.home_living_nav store={@store} cart_count={@cart_count} on_dark={true} active_path="/" />

      <%!-- Background photographic layer --%>
      <%= if @hero_image_url do %>
        <img
          src={@hero_image_url}
          alt="Home interior"
          class="absolute inset-0 w-full h-full object-cover opacity-60"
        />
        <div class="absolute inset-0 bg-gradient-to-br from-[#1F2937]/90 via-[#1F2937]/60 to-transparent">
        </div>
      <% else %>
        <div class="absolute inset-0 bg-gradient-to-br from-[#1F2937] via-[#374151] to-[#1F2937]">
        </div>
      <% end %>

      <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-20 sm:pt-16 sm:pb-32 lg:pb-40">
        <div class="max-w-2xl">
          <h1 class="home-living-display text-4xl sm:text-6xl lg:text-7xl text-white mb-6">
            {@headline}
          </h1>
          <p
            :if={@subheadline}
            class="text-base sm:text-lg text-white/75 leading-relaxed mb-8 max-w-lg"
          >
            {@subheadline}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex items-center gap-2 px-7 py-4 rounded-full bg-[#84CC16] text-[#1F2937] text-sm font-semibold hover:bg-white transition-colors min-h-[48px]"
          >
            {@cta_label}
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>

        <%!-- Floating feature tiles overlay (bottom-right) — Furniora --%>
        <div
          :if={@tile_products != []}
          class="hidden md:flex absolute bottom-8 right-8 lg:bottom-12 lg:right-12 gap-3"
        >
          <a
            :for={{product, idx} <- Enum.with_index(@tile_products)}
            href={store_path(@store.slug, "/products/#{product.slug}")}
            class="block w-40 h-40 rounded-2xl overflow-hidden bg-white/10 backdrop-blur-md ring-1 ring-white/20 group hover:ring-[#84CC16] transition-all"
          >
            <div class="relative w-full h-full">
              <img
                :if={Shared.first_image(product)}
                src={Shared.first_image(product)}
                alt={product.title}
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
              />
              <div
                :if={!Shared.first_image(product)}
                class="w-full h-full flex items-center justify-center bg-[#374151]"
              >
                <span class="material-symbols-outlined text-white/40" style="font-size: 56px;">
                  {tile_icon(idx)}
                </span>
              </div>
              <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-[#1F2937] to-transparent p-3">
                <p class="text-xs font-semibold text-white truncate">
                  {product.title}
                </p>
                <span class="material-symbols-outlined text-[#84CC16]" style="font-size: 14px;">
                  arrow_outward
                </span>
              </div>
            </div>
          </a>
        </div>
      </div>
    </section>
    """
  end

  # Verbatim from home.ex: a configured carousel image wins, then the single
  # hero image_url, else no photograph at all.
  defp theme_hero_image_url(theme) do
    case get_in(theme, [:hero, :images]) || [] do
      [first | _] when is_binary(first) ->
        first

      _ ->
        case get_in(theme, [:hero, :image_url]) do
          url when is_binary(url) and url != "" -> url
          _ -> nil
        end
    end
  end

  defp tile_icon(0), do: "lightbulb"
  defp tile_icon(_idx), do: "weekend"

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
