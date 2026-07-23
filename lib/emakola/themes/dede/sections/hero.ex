defmodule Emakola.Themes.Dede.Sections.Hero do
  @moduledoc """
  Dede home hero — the hand-painted signboard over the chop bar door.

  Carries the page's `<h1>`. Deliberately short on a phone: a hungry
  customer should reach the menu in one thumb-flick. Photo-optional by
  design — with no image the signboard is pure paint: the store's name at
  display scale in chalk on the bottle-green board. WhatsApp ordering is a
  first-class action beside the menu CTA, never a footnote.

  The CTA links only to the server-generated products path — a
  merchant-controlled href here would be a stored-XSS sink, so no URL
  setting exists. The image setting renders local upload paths only,
  mirroring Atelier's `valid_hero_image?/1`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Dede.Shared

  @impl true
  def key, do: "dede/hero"
  @impl true
  def label, do: "Signboard"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "See the menu"},
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
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "See the menu")
      |> assign(:hero_product, hero_product)
      |> assign(
        :image,
        valid_image(assigns.settings["image_url"]) ||
          (hero_product && Emakola.Themes.Dede.Shared.first_image(hero_product))
      )
      |> assign(:whatsapp, Shared.whatsapp_link(assigns.store))

    ~H"""
    <section
      class="bg-[#1B2E23] px-4 py-8 sm:px-6 sm:py-12 lg:px-8"
      aria-labelledby="dede-hero-heading"
    >
      <div class={[
        "mx-auto max-w-[880px]",
        @image && "grid gap-6 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center"
      ]}>
        <div>
          <p
            :if={@custom_headline}
            class="mb-2 text-[0.6875rem] font-bold uppercase tracking-[0.2em] text-[#A8BAA5]"
          >
            {@store.name}
          </p>
          <h1
            id="dede-hero-heading"
            class="text-4xl uppercase leading-[0.95] tracking-wide text-[#F3EDDF] [font-family:var(--dt-heading-font,'Anton',sans-serif)] sm:text-5xl lg:text-6xl"
          >
            {@headline}
          </h1>
          <p :if={@subheadline} class="mt-3 max-w-xl text-base leading-relaxed text-[#A8BAA5]">
            {@subheadline}
          </p>
          <div class="mt-6 flex flex-wrap items-center gap-3">
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex min-h-12 items-center rounded-full bg-[#F3EDDF] px-6 text-[0.9375rem] font-bold text-[#1B2E23] hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF] focus-visible:ring-offset-2 focus-visible:ring-offset-[#1B2E23] motion-safe:transition-colors motion-safe:active:scale-[0.98]"
            >
              {@cta_label}
            </a>
            <a
              :if={@whatsapp}
              href={@whatsapp}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex min-h-12 items-center gap-2 rounded-full bg-whatsapp px-6 text-[0.9375rem] font-bold text-white hover:bg-whatsapp-dark focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF] focus-visible:ring-offset-2 focus-visible:ring-offset-[#1B2E23] motion-safe:transition-colors motion-safe:active:scale-[0.98]"
            >
              <svg class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d={Shared.whatsapp_glyph()} />
              </svg>
              Order on WhatsApp
            </a>
          </div>
        </div>
        <div :if={@image} class="relative sm:w-64">
          <div class="overflow-hidden rounded-2xl border-2 border-[#F3EDDF]/15">
            <.optimized_image
              src={@image}
              alt={(@hero_product && @hero_product.title) || "#{@store.name} kitchen"}
              priority={:high}
              width={512}
              height={512}
              class="aspect-square w-full object-cover"
            />
          </div>
          <div
            :if={@hero_product}
            class="absolute -bottom-4 -left-3 max-w-[13rem] rounded-xl bg-[#F3EDDF] px-4 py-2.5 shadow-lg"
          >
            <p class="truncate text-xs font-semibold text-[#2B1B12]">{@hero_product.title}</p>
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
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil

  # Local upload paths only — the write path (HomeSections.sanitize_entry)
  # already blocks non-http(s) schemes for :image_url settings; this
  # render-side gate additionally keeps remote URLs out of the src position.
  defp valid_image(url) when is_binary(url) do
    if Emakola.Storage.trusted_media_url?(url), do: url, else: nil
  end

  defp valid_image(_url), do: nil
end
