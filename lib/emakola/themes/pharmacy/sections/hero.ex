defmodule Emakola.Themes.Pharmacy.Sections.Hero do
  @moduledoc """
  Pharmacy home hero — forest-green photographic band with the serif
  headline and the cream pill CTA. Extracted verbatim from
  `pharmacy/home.ex`.

  Settings default to `""` so an untouched store keeps rendering the
  merchant's existing `@theme.hero` config — the section editor only takes
  over a field once the merchant fills it in.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/hero"

  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "title", type: :string, label: "Headline", default: ""},
      %{key: "subtitle", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_text", type: :string, label: "Button label", default: ""},
      %{key: "image_url", type: :image_url, label: "Hero image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :hero_image, hero_image(assigns))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :hero)}
      class="relative overflow-hidden bg-[#14543E]"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-20 lg:py-24 relative">
        <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <%!-- Left: copy --%>
          <div class="relative z-10 order-2 lg:order-1">
            <span class="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-[#A7E5C5]/20 text-[#A7E5C5] text-xs font-semibold uppercase tracking-wider mb-6">
              <span class="material-symbols-outlined" style="font-size: 14px;">verified</span>
              Pharmacy you can trust
            </span>
            <h1 class="pharmacy-heading text-4xl sm:text-5xl lg:text-6xl font-medium text-white leading-[1.1] mb-6">
              {if @settings["title"] not in [nil, ""],
                do: @settings["title"],
                else: @theme.hero.title || "Professional Pharmacy Services You Can Trust"}
            </h1>
            <p class="text-base sm:text-lg text-[#F9F6F0]/80 leading-relaxed mb-8 max-w-xl">
              {if @settings["subtitle"] not in [nil, ""],
                do: @settings["subtitle"],
                else:
                  @theme.hero.subtitle ||
                    @store.description ||
                    "Providing expert pharmacy care you can rely on. We are here to support your health every step of the way."}
            </p>
            <div class="flex flex-col sm:flex-row gap-3">
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-white text-[#14543E] text-sm font-semibold hover:bg-[#A7E5C5] transition-colors min-h-[48px]"
              >
                {if @settings["cta_text"] not in [nil, ""],
                  do: @settings["cta_text"],
                  else: @theme.hero.cta_text || "Explore Now"}
                <span class="material-symbols-outlined" style="font-size: 18px;">
                  arrow_forward
                </span>
              </a>
              <a
                href={store_path(@store.slug, "/about")}
                class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full border border-[#A7E5C5]/40 text-white text-sm font-semibold hover:bg-white/5 transition-colors min-h-[48px]"
              >
                Learn more
              </a>
            </div>
          </div>

          <%!-- Right: photographic frame --%>
          <div class="relative order-1 lg:order-2">
            <div class="aspect-[4/3] rounded-3xl overflow-hidden bg-[#A7E5C5]/10 ring-1 ring-white/10">
              <%= if @hero_image do %>
                <img src={@hero_image} alt="Pharmacy" class="w-full h-full object-cover" />
              <% else %>
                <div class="w-full h-full bg-gradient-to-br from-[#1A6E4F] via-[#14543E] to-[#0F3F2E] flex items-center justify-center">
                  <span class="material-symbols-outlined text-[#A7E5C5]/30" style="font-size: 120px;">
                    local_pharmacy
                  </span>
                </div>
              <% end %>
            </div>
            <%!-- floating trust card (only for platform-verified stores) --%>
            <div
              :if={Map.get(@store, :verified)}
              class="absolute bottom-6 left-6 sm:bottom-8 sm:left-8 bg-white/95 backdrop-blur-md rounded-2xl px-5 py-4 shadow-xl"
            >
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-[#A7E5C5] flex items-center justify-center">
                  <span class="material-symbols-outlined text-[#14543E]" style="font-size: 22px;">
                    verified_user
                  </span>
                </div>
                <p class="text-sm font-bold text-[#14543E]">Verified Pharmacy</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # A merchant-typed hero image (sanitized by HomeSections as an :image_url
  # setting) wins; otherwise the theme's own hero images, exactly as the
  # pre-section home resolved them.
  defp hero_image(assigns) do
    case assigns.settings["image_url"] do
      url when is_binary(url) and url != "" -> url
      _ -> theme_hero_image(assigns.theme)
    end
  end

  defp theme_hero_image(theme) do
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
