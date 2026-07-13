defmodule Emakola.Themes.Spotlight.Sections.Hero do
  @moduledoc """
  Spotlight home hero — extracted verbatim from spotlight/home.ex.

  Carries the page's `<h1>`, which is the hero product's title when the
  store has one and the theme's `hero.title` when it does not. Settings are
  additive: a blank default falls back to the theme-config expression the
  block used before the section retrofit, so an untouched storefront renders
  byte-identically.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Spotlight.Shared

  @impl true
  def key, do: "spotlight/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "overline", type: :string, label: "Overline", default: ""},
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "tagline", type: :text, label: "Tagline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""},
      %{key: "badge", type: :string, label: "Badge", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    hero = get_in(assigns.theme, [:hero]) || %{}
    hero_product = assigns |> Map.get(:products, []) |> List.first()

    assigns =
      assigns
      |> assign(:hero, hero)
      |> assign(:hero_product, hero_product)
      |> assign(
        :overline,
        present(assigns.settings["overline"]) ||
          Map.get(hero, :overline, "The one you reach for")
      )
      |> assign(
        :headline,
        present(assigns.settings["headline"]) ||
          if(hero_product, do: hero_product.title, else: Map.get(hero, :title, "One product."))
      )
      |> assign(:tagline, present(assigns.settings["tagline"]) || Map.get(hero, :tagline))
      |> assign(
        :cta_label,
        present(assigns.settings["cta_label"]) || Map.get(hero, :cta_text, "Choose yours")
      )
      |> assign(:badge, present(assigns.settings["badge"]) || Map.get(hero, :badge))

    ~H"""
    <section class="relative overflow-hidden">
      <div class="absolute -top-24 -right-24 w-96 h-96 rounded-full spot-blob opacity-60"></div>
      <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24 grid lg:grid-cols-2 gap-10 items-center relative">
        <div>
          <p class="text-xs uppercase tracking-[0.25em] text-[var(--theme-accent,#7C3AED)] font-semibold">
            {@overline}
          </p>
          <h1 class="spot-display text-5xl sm:text-6xl lg:text-7xl text-[#16130F] mt-4 uppercase">
            {@headline}
          </h1>
          <p class="text-[#6B675F] text-base mt-5 max-w-md leading-relaxed">
            {@tagline}
          </p>
          <div :if={@hero_product} class="mt-7">
            <a
              href={store_path(@store.slug, "/products/#{@hero_product.slug}")}
              class="inline-block rounded-full spot-cta px-8 py-3.5 text-sm font-semibold uppercase tracking-wider"
            >
              {@cta_label}
            </a>
            <p
              :if={@badge not in [nil, ""]}
              class="text-[11px] uppercase tracking-wider text-[#7A7468] mt-4"
            >
              {@badge}
            </p>
          </div>
          <p :if={!@hero_product} class="mt-7 text-[#6B675F]">
            Our product launches soon — check back shortly.
          </p>
        </div>
        <div class="relative">
          <div class="rounded-3xl overflow-hidden bg-white border border-[#ECE7DE] aspect-[4/5]">
            <.optimized_image
              :if={@hero_product && Shared.first_image(@hero_product)}
              src={Shared.first_image(@hero_product)}
              alt={@hero_product.title}
              class="w-full h-full object-cover"
            />
            <div
              :if={!(@hero_product && Shared.first_image(@hero_product))}
              class="w-full h-full flex items-center justify-center bg-[#F3EFE8]"
            >
              <span class="material-symbols-outlined text-[#d8d0c2] text-6xl">image</span>
            </div>
          </div>
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
