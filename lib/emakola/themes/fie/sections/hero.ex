defmodule Emakola.Themes.Fie.Sections.Hero do
  @moduledoc """
  Fie home hero — the catalogue cover.

  Carries the page's `<h1>`. Photo-optional by design: the cover plate is
  a typographic composition on the blush ground by default — the store's
  initial at monumental scale inside the hairline frame — so the page is
  composed before any image bytes arrive. A local upload turns the plate
  photographic; the type never moves.

  The index line above the headline states only a true count (the
  collections, which the home page loads in full — the product preview is
  capped upstream, so no piece count renders) and withdraws entirely for
  a store without collections — the index encodes real structure or it
  doesn't render.

  The CTA always links to the server-generated products path — a
  merchant-controlled href here would be a stored-XSS sink, so no URL
  setting exists. The image setting only renders local upload paths,
  mirroring Market's `valid_image/1`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Fie.Components

  @impl true
  def key, do: "fie/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "Browse the catalogue"},
      %{key: "image_url", type: :image_url, label: "Cover image", default: ""}
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
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Browse the catalogue")
      |> assign(:hero_product, hero_product)
      |> assign(
        :image,
        valid_image(assigns.settings["image_url"]) ||
          (hero_product && Emakola.Themes.Fie.Shared.first_image(hero_product))
      )
      |> assign(:index_line, index_line(length(Map.get(assigns, :categories) || [])))

    ~H"""
    <section class="border-b border-[#EBDAD3] bg-[#FDFCFB]" aria-labelledby="fie-hero-heading">
      <div class="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8 lg:py-16">
        <div class="mb-8 flex items-baseline justify-between gap-4 border-b border-[#EBDAD3] pb-4 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
          <span>Catalogue</span>
          <span :if={@index_line} class="tabular-nums normal-case tracking-normal">
            {@index_line}
          </span>
        </div>

        <div class="grid gap-10 lg:grid-cols-[3fr_2fr] lg:items-center lg:gap-16">
          <div class="max-w-2xl">
            <p
              :if={@custom_headline}
              class="mb-3 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500"
            >
              {@store.name}
            </p>
            <h1
              id="fie-hero-heading"
              class="text-4xl font-medium leading-[1.05] tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif] sm:text-5xl lg:text-6xl"
            >
              {@headline}
            </h1>
            <p
              :if={@subheadline}
              class="mt-5 max-w-xl text-base leading-relaxed text-stone-600 sm:text-lg"
            >
              {@subheadline}
            </p>
            <a
              href={store_path(@store.slug, "/products")}
              class="mt-8 inline-flex min-h-[48px] items-center gap-3 bg-store-accent px-7 py-3.5 text-sm font-semibold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
            >
              {@cta_label}
              <svg
                class="h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
          </div>

          <div class="relative aspect-[4/5] max-h-[520px] w-full overflow-hidden border border-[#EBDAD3] bg-[#F7ECE7]">
            <div class="absolute inset-0 flex flex-col items-center justify-center gap-4">
              <span
                class="select-none text-[7rem] font-medium leading-none text-[#D8BCB0] [font-family:'Space_Grotesk','Inter',sans-serif] lg:text-[9rem]"
                aria-hidden="true"
              >
                {String.first(@store.name)}
              </span>
              <span class="text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
                {@store.name}
              </span>
            </div>
            <.optimized_image
              :if={@image}
              src={@image}
              alt={(@hero_product && @hero_product.title) || "#{@store.name} catalogue cover"}
              priority={:high}
              width={640}
              height={800}
              class="absolute inset-0 h-full w-full object-cover"
            />
            <div
              :if={@image && @hero_product}
              class="absolute bottom-4 left-4 max-w-[14rem] border border-[#EBDAD3] bg-white px-4 py-2.5 shadow-sm"
            >
              <p class="truncate text-xs font-semibold text-stone-900">{@hero_product.title}</p>
              <p class="text-xs font-semibold tabular-nums text-store-accent">
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

  # Collections load in full on the home page, so their count is true.
  # Products arrive as a capped preview — a piece count here could lie
  # for larger stores, so none renders.
  defp index_line(0), do: nil
  defp index_line(collections), do: Components.count_label(collections, "collection")

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil

  # Local upload paths only — mirrors Market's valid_image/1. The write
  # path (HomeSections.sanitize_entry) already blocks non-http(s) schemes
  # for :image_url settings; this render-side gate additionally keeps
  # remote URLs out of the src position.
  defp valid_image(url) when is_binary(url) do
    if String.starts_with?(url, "/uploads/") or String.starts_with?(url, "/images/"),
      do: url,
      else: nil
  end

  defp valid_image(_url), do: nil
end
