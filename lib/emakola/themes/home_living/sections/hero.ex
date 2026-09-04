defmodule Emakola.Themes.HomeLiving.Sections.Hero do
  @moduledoc """
  Home Living home hero — extracted verbatim from home_living/home.ex.

  The dark charcoal, photographic signboard: bold uppercase headline and
  lime CTA. It carries the page's single `<h1>`, which reads as the store's
  own name until the merchant writes a headline. The two floating product
  tiles that used to sit bottom-right are gone: they showed the first two
  products, which the grid and the featured pick below already carry, and a
  home must not show the same photo twice. The background is only ever an
  image the merchant chose.

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

    assigns =
      assigns
      |> assign(:cart_count, Map.get(assigns, :cart_count) || 0)
      |> assign(
        :hero_image_url,
        present(assigns.settings["image_url"]) || theme_hero_image_url(assigns.theme)
      )
      |> assign(
        :headline,
        present(assigns.settings["headline"]) || present(Map.get(hero, :title)) ||
          assigns.store.name
      )
      |> assign(
        :subheadline,
        present(assigns.settings["subheadline"]) || present(Map.get(hero, :subtitle)) ||
          present(Map.get(assigns.store, :description))
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
        <%!-- Decorative: the headline sits on top of it, so it carries no
             alt text — and no theme-written one like "Home interior". --%>
        <img
          src={@hero_image_url}
          alt=""
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

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
