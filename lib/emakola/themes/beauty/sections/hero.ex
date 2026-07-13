defmodule Emakola.Themes.Beauty.Sections.Hero do
  @moduledoc """
  Beauty home hero — dark walnut band with a photographic portrait, the
  dramatic Cormorant headline, a cream pill CTA and the botanical badge.

  Beauty's nav lives *inside* the hero band (`on_dark`), sharing its walnut
  background: it was written that way and moving it into the page chrome
  would change the storefront's rendered output, so it is extracted here
  verbatim along with the rest of the block.

  Merchant settings override the theme's `hero.*` config; blank falls back
  to it, so an untouched store renders exactly as it did pre-retrofit.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Beauty.Shared

  @impl true
  def key, do: "beauty/hero"

  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""},
      %{key: "image_url", type: :image_url, label: "Hero image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={section_enabled?(@theme, :hero)} class="relative bg-[#6B4423]">
      <Shared.beauty_nav store={@store} cart_count={assigns[:cart_count] || 0} on_dark={true} />

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-16 sm:pt-16 sm:pb-24">
        <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <div class="relative z-10 order-2 lg:order-1">
            <span class="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-[#C9925E]/20 text-[#C9925E] text-[11px] font-semibold uppercase tracking-[0.2em] mb-6">
              <span class="material-symbols-outlined" style="font-size: 14px;">spa</span>
              Botanical Beauty
            </span>
            <h1 class="beauty-heading text-5xl sm:text-6xl lg:text-7xl font-semibold text-[#FAF6EE] leading-[1.05] mb-6">
              {if @settings["headline"] not in [nil, ""],
                do: @settings["headline"],
                else: @theme.hero.title || "Elevate Your Essence"}
            </h1>
            <p class="text-base sm:text-lg text-[#FAF6EE]/80 leading-relaxed mb-8 max-w-lg">
              {if @settings["subheadline"] not in [nil, ""],
                do: @settings["subheadline"],
                else:
                  @theme.hero.subtitle ||
                    @store.description ||
                    "Botanical skincare and beauty essentials — crafted for melanin-rich skin."}
            </p>
            <div class="flex flex-col sm:flex-row gap-3">
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-[#FAF6EE] text-[#6B4423] text-sm font-semibold hover:bg-white transition-colors min-h-[48px]"
              >
                {if @settings["cta_label"] not in [nil, ""],
                  do: @settings["cta_label"],
                  else: @theme.hero.cta_text || "Shop the Collection"}
                <span class="material-symbols-outlined" style="font-size: 18px;">
                  arrow_forward
                </span>
              </a>
              <a
                href={store_path(@store.slug, "/about")}
                class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full border border-[#C9925E]/40 text-[#FAF6EE] text-sm font-semibold hover:bg-white/5 transition-colors min-h-[48px]"
              >
                Our Story
              </a>
            </div>
          </div>

          <div class="relative order-1 lg:order-2">
            <div class="aspect-[4/5] rounded-3xl overflow-hidden bg-[#C9925E]/10 ring-1 ring-[#C9925E]/20">
              <%= if hero_image_url(assigns) do %>
                <img
                  src={hero_image_url(assigns)}
                  alt="Beauty hero"
                  class="w-full h-full object-cover"
                />
              <% else %>
                <div class="w-full h-full bg-gradient-to-br from-[#8A5A33] via-[#6B4423] to-[#3D2F25] flex items-center justify-center">
                  <span
                    class="material-symbols-outlined text-[#C9925E]/30"
                    style="font-size: 140px;"
                  >
                    spa
                  </span>
                </div>
              <% end %>
            </div>
            <%!-- floating tagline card --%>
            <div class="absolute bottom-6 right-6 sm:bottom-8 sm:right-8 max-w-[240px] bg-[#3D2F25]/85 backdrop-blur-md rounded-2xl px-5 py-4 text-[#FAF6EE]">
              <p class="beauty-heading text-sm font-semibold mb-1">Beauty, Personalized Care</p>
              <p class="text-xs text-[#FAF6EE]/75 leading-relaxed">
                Each formula is thoughtfully designed to highlight your natural elegance.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp section_enabled?(theme, name) do
    case get_in(theme, [:sections, name]) do
      false -> false
      _ -> true
    end
  end

  defp hero_image_url(assigns) do
    case assigns.settings["image_url"] do
      url when is_binary(url) and url != "" -> url
      _ -> theme_image_url(assigns.theme)
    end
  end

  defp theme_image_url(theme) do
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
end
