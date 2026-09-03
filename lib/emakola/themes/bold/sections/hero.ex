defmodule Emakola.Themes.Bold.Sections.Hero do
  @moduledoc """
  Bold home hero — full-bleed dark band, massive headline — extracted
  verbatim from bold/home.ex.

  Merchant settings override the theme config; left empty (the default),
  the headline and button fall back to `@theme.hero`, and the subheadline
  to the store's own description — never to the theme's sample line
  ("Curated goods for the discerning eye"), which spoke for every store.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Bold.Shared

  @impl true
  def key, do: "bold/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Headline", default: ""},
      %{key: "subheading", type: :string, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""},
      %{key: "image_url", type: :image_url, label: "Background image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    settings = assigns[:settings] || %{}
    hero = get_in(assigns.theme, [:hero]) || %{}

    assigns =
      assigns
      |> assign(:hero_image, override(settings["image_url"], Map.get(hero, :image_url)))
      |> assign(:hero_title, override(settings["heading"], Map.get(hero, :title) || "The Edit"))
      |> assign(
        :hero_subtitle,
        override(
          settings["subheading"],
          override(Map.get(hero, :subtitle), Map.get(assigns.store, :description))
        )
      )
      |> assign(
        :hero_cta,
        override(settings["cta_label"], Map.get(hero, :cta_text) || "Shop the Collection")
      )

    ~H"""
    <section :if={Shared.section_enabled?(@theme, :hero)} class="relative overflow-hidden">
      <%= if @hero_image && @hero_image != "" do %>
        <div class="relative min-h-[70vh] sm:min-h-[80vh] flex items-center">
          <.optimized_image
            src={@hero_image}
            alt=""
            priority={:high}
            class="absolute inset-0 w-full h-full object-cover"
          />
          <div class="absolute inset-0 bg-[#0F172A]/70"></div>
          <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-20 sm:py-28 lg:py-36 w-full">
            <.hero_content
              store={@store}
              hero_title={@hero_title}
              hero_subtitle={@hero_subtitle}
              hero_cta={@hero_cta}
            />
          </div>
        </div>
      <% else %>
        <div class="relative min-h-[70vh] sm:min-h-[80vh] flex items-center bg-gradient-to-br from-[#0F172A] via-[#1E293B] to-[#0F172A]">
          <div class="absolute inset-0 opacity-[0.03]">
            <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <pattern
                  id="bold-grid"
                  x="0"
                  y="0"
                  width="60"
                  height="60"
                  patternUnits="userSpaceOnUse"
                >
                  <path
                    d="M60 0 L0 0 L0 60"
                    fill="none"
                    stroke="white"
                    stroke-width="0.5"
                  />
                </pattern>
              </defs>
              <rect width="100%" height="100%" fill="url(#bold-grid)" />
            </svg>
          </div>
          <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-20 sm:py-28 lg:py-36 w-full">
            <.hero_content
              store={@store}
              hero_title={@hero_title}
              hero_subtitle={@hero_subtitle}
              hero_cta={@hero_cta}
            />
          </div>
        </div>
      <% end %>
    </section>
    """
  end

  # ── Hero Content Component ──

  attr :store, :map, required: true
  attr :hero_title, :string, default: nil
  attr :hero_subtitle, :string, default: nil
  attr :hero_cta, :string, default: nil

  defp hero_content(assigns) do
    ~H"""
    <div class="max-w-3xl">
      <p
        class="text-xs sm:text-sm font-semibold tracking-[0.3em] uppercase text-[#F59E0B] mb-6"
        style="font-family: 'Inter', sans-serif;"
      >
        {@store.name}
      </p>
      <h1
        class="text-5xl sm:text-6xl lg:text-7xl xl:text-8xl font-black text-white leading-[0.95] mb-6 tracking-tight"
        style="font-family: 'Outfit', sans-serif;"
      >
        {@hero_title}
      </h1>
      <p
        :if={Shared.present?(@hero_subtitle)}
        class="text-lg sm:text-xl text-slate-300 leading-relaxed mb-10 max-w-lg font-light"
        style="font-family: 'Inter', sans-serif;"
      >
        {@hero_subtitle}
      </p>
      <a
        href={store_path(@store.slug, "/products")}
        class="inline-flex items-center gap-3 px-8 py-4 bg-[#F59E0B] text-[#0F172A] text-sm font-bold tracking-wide uppercase hover:bg-[#D97706] active:scale-[0.97] transition-all"
        style="font-family: 'Inter', sans-serif;"
      >
        {@hero_cta}
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
          />
        </svg>
      </a>
    </div>
    """
  end

  # A merchant setting wins only when they actually wrote one — an empty
  # setting (the schema default) leaves the pre-retrofit value untouched.
  defp override(setting, fallback) when setting in [nil, ""], do: fallback
  defp override(setting, _fallback), do: setting
end
