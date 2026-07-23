defmodule Emakola.Themes.Market.Sections.Hero do
  @moduledoc """
  Market home hero — the stall's signboard (spec:
  docs/superpowers/specs/2026-07-12-market-theme-elevation.md).

  Carries the page's `<h1>`. Photo-optional by design: with no image the
  hero is a typographic composition on warm stone — a display-scale
  headline in the merchant's heading family anchored by the store's
  initial at monumental scale, the theme's placeholder glyph language.
  With a local upload it becomes a stall front: text beside a
  product-forward photo in the card family's rounded frame.

  The CTA is a notched tag (the price-chip geometry writ large) and always
  links to the server-generated products path — a merchant-controlled href
  here would be a stored-XSS sink, so no URL setting exists. The image
  setting only renders local upload paths, mirroring Atelier's
  `valid_hero_image?/1`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  @impl true
  def key, do: "market/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "Shop all"},
      %{key: "image_url", type: :image_url, label: "Image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    # Photo-FALLBACK, not photo-optional: the hero used to show an image only
    # if the merchant had set one in the editor — which no new store has — so
    # every real storefront opened on an empty band. It now falls back to the
    # shop's own first product photograph.
    hero_product = assigns |> Map.get(:products, []) |> List.first()

    custom_headline = present(assigns.settings["headline"])

    assigns =
      assigns
      |> assign(:custom_headline, custom_headline)
      |> assign(:headline, custom_headline || assigns.store.name)
      |> assign(
        :subheadline,
        present(assigns.settings["subheadline"]) || present(assigns.store.description)
      )
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Shop all")
      |> assign(:hero_product, hero_product)
      |> assign(
        :image,
        valid_image(assigns.settings["image_url"]) ||
          (hero_product && Emakola.Themes.Market.Shared.first_image(hero_product))
      )

    ~H"""
    <section
      class="relative overflow-hidden border-b border-stone-200 bg-stone-50"
      aria-labelledby="market-hero-heading"
    >
      <span
        :if={!@image}
        class="pointer-events-none absolute -right-6 top-1/2 hidden -translate-y-1/2 select-none text-[15rem] font-bold leading-none text-stone-200 [font-family:var(--dt-heading-font,inherit)] sm:block lg:text-[20rem]"
        aria-hidden="true"
      >
        {String.first(@store.name)}
      </span>
      <div class={[
        "relative mx-auto max-w-[1280px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8 lg:py-16",
        @image && "grid gap-8 lg:grid-cols-2 lg:items-center lg:gap-12"
      ]}>
        <div class="max-w-2xl">
          <p
            :if={@custom_headline}
            class="mb-3 text-[0.6875rem] font-bold uppercase tracking-[0.18em] text-stone-500"
          >
            {@store.name}
          </p>
          <h1
            id="market-hero-heading"
            class="text-4xl font-bold leading-[1.05] tracking-tight text-stone-900 [font-family:var(--dt-heading-font,inherit)] sm:text-5xl lg:text-6xl"
          >
            {@headline}
          </h1>
          <p
            :if={@subheadline}
            class="mt-4 max-w-xl text-base leading-relaxed text-stone-600 sm:text-lg"
          >
            {@subheadline}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="group mt-7 inline-block focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 focus-visible:ring-offset-stone-50"
          >
            <span class={[
              "flex items-center gap-2 bg-store-accent py-3.5 pl-6 pr-8",
              "text-[0.9375rem] font-bold leading-none text-white",
              "[clip-path:polygon(0_0,calc(100%_-_12px)_0,100%_12px,100%_100%,0_100%)]",
              "motion-safe:transition-opacity group-hover:opacity-90 motion-safe:group-active:scale-[0.98]"
            ]}>
              {@cta_label}
              <svg
                class="h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </span>
          </a>
        </div>
        <div :if={@image} class="relative">
          <div class="overflow-hidden rounded-[20px] border border-stone-200 bg-white">
            <.optimized_image
              src={@image}
              alt={(@hero_product && @hero_product.title) || "#{@store.name} storefront"}
              priority={:high}
              width={640}
              height={480}
              class="aspect-[4/3] w-full object-cover"
            />
          </div>
          <div
            :if={@hero_product}
            class="absolute -bottom-4 left-5 flex max-w-[15rem] items-center gap-3 rounded-full border border-stone-200 bg-white py-2 pl-2 pr-5 shadow-lg"
          >
            <span class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-store-accent/10 text-[0.6875rem] font-bold uppercase text-store-accent">
              {String.first(@hero_product.title)}
            </span>
            <div class="min-w-0">
              <p class="truncate text-xs font-semibold text-stone-900">{@hero_product.title}</p>
              <p class="text-xs font-bold tabular-nums text-store-accent">
                {EmakolaWeb.Helpers.Currency.format_price_range(
                  @hero_product.min_price,
                  @hero_product.max_price,
                  @store.currency
                )}
              </p>
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

  # Platform-owned media URLs only — mirrors Atelier's valid_hero_image?/1. The
  # write path (HomeSections.sanitize_entry) already blocks non-http(s)
  # schemes for :image_url settings; this render-side gate additionally
  # keeps remote URLs out of the src position.
  defp valid_image(url) when is_binary(url) do
    if Emakola.Storage.trusted_media_url?(url), do: url, else: nil
  end

  defp valid_image(_url), do: nil
end
