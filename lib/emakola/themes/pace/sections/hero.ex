defmodule Emakola.Themes.Pace.Sections.Hero do
  @moduledoc """
  Pace home hero — kinetic type over the ghost marquee.

  Carries the page's `<h1>`. Photo-optional by design: with no image the
  hero is a typographic composition — the headline in uppercase italics
  over the ghost wordmark drifting behind it. The marquee is atmosphere,
  not a banner: decorative (`aria-hidden`), ghost-light, and animated
  only inside `prefers-reduced-motion: no-preference` (see
  `Shared.theme_styles/1`); with the preference set it renders as a
  static composed crop.

  The CTA always links to the server-generated products path — a
  merchant-controlled href here would be a stored-XSS sink, so no URL
  setting exists. The image setting only renders local upload paths,
  mirroring Market's `valid_image/1`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  @impl true
  def key, do: "pace/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "Shop the lineup"},
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
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Shop the lineup")
      |> assign(:hero_product, hero_product)
      |> assign(
        :image,
        valid_image(assigns.settings["image_url"]) ||
          (hero_product && Emakola.Themes.Pace.Shared.first_image(hero_product))
      )
      |> assign(:marquee_copy, String.duplicate("#{String.upcase(assigns.store.name)} /// ", 4))

    ~H"""
    <section class="relative overflow-hidden" aria-labelledby="pace-hero-heading">
      <%!-- Ghost marquee: the wordmark drifting behind the headline.
      Decorative and unselectable; the animation only exists for users
      who have not asked for reduced motion. --%>
      <div
        class="pointer-events-none absolute inset-x-0 top-1/2 -translate-y-1/2 overflow-hidden"
        aria-hidden="true"
      >
        <div class="pace-marquee flex w-max">
          <span class="pace-display select-none whitespace-nowrap text-[6rem] font-bold italic leading-none text-[#EDF4F9] [-webkit-text-stroke:1.5px_#D3E2ED] sm:text-[9rem] lg:text-[12rem]">
            {@marquee_copy}
          </span>
          <span class="pace-display select-none whitespace-nowrap text-[6rem] font-bold italic leading-none text-[#EDF4F9] [-webkit-text-stroke:1.5px_#D3E2ED] sm:text-[9rem] lg:text-[12rem]">
            {@marquee_copy}
          </span>
        </div>
      </div>

      <div class={[
        "relative mx-auto max-w-[1280px] px-5 py-14 sm:px-8 sm:py-20 lg:px-10 lg:py-24",
        @image && "grid gap-8 lg:grid-cols-2 lg:items-center lg:gap-12"
      ]}>
        <div class="max-w-2xl">
          <p
            :if={@custom_headline}
            class="mb-3 text-[0.6875rem] font-bold uppercase tracking-[0.18em] text-slate-500"
          >
            <span aria-hidden="true">///</span> {@store.name}
          </p>
          <h1
            id="pace-hero-heading"
            class="pace-display text-4xl font-bold uppercase italic leading-[1.02] tracking-tight text-slate-950 sm:text-5xl lg:text-6xl"
          >
            {@headline}
          </h1>
          <p
            :if={@subheadline}
            class="mt-4 max-w-xl text-base leading-relaxed text-slate-600 sm:text-lg"
          >
            {@subheadline}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="group mt-8 inline-flex items-center gap-2.5 rounded-full bg-store-accent py-3.5 pl-7 pr-6 text-[0.9375rem] font-bold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
          >
            {@cta_label}
            <span
              class="pace-display text-xs italic tracking-tight motion-safe:transition-transform motion-safe:group-hover:translate-x-0.5"
              aria-hidden="true"
            >
              ///
            </span>
          </a>
        </div>
        <div
          :if={@image}
          class="relative overflow-hidden rounded-[24px] bg-gradient-to-b from-slate-800 to-slate-950"
        >
          <.optimized_image
            src={@image}
            alt={(@hero_product && @hero_product.title) || "#{@store.name} gear"}
            priority={:high}
            width={640}
            height={480}
            class="aspect-[4/3] w-full object-cover"
          />
          <div
            class="absolute inset-0 bg-gradient-to-t from-slate-950/60 to-transparent"
            aria-hidden="true"
          >
          </div>
          <div
            :if={@hero_product}
            class="absolute bottom-4 left-4 max-w-[15rem] rounded-2xl bg-white/95 px-4 py-2.5 backdrop-blur"
          >
            <p class="truncate text-xs font-semibold uppercase tracking-wide text-slate-900">
              {@hero_product.title}
            </p>
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

  # Local upload paths only — mirrors Market/Atelier. The write path
  # (HomeSections.sanitize_entry) already blocks non-http(s) schemes for
  # :image_url settings; this render-side gate additionally keeps remote
  # URLs out of the src position.
  defp valid_image(url) when is_binary(url) do
    if Emakola.Storage.trusted_media_url?(url), do: url, else: nil
  end

  defp valid_image(_url), do: nil
end
