defmodule Emakola.Themes.Ntoma.Sections.Hero do
  @moduledoc """
  Ntoma home hero — the editorial opening spread.

  Carries the page's `<h1>`. Type-first by design: with no photograph the
  hero is a finished composition — the store's name (or the merchant's
  headline) in oversized Fraunces display capitals over the calico ground,
  anchored by the woven selvedge strip. With a local upload it becomes the
  print-photography spread the reference calls for: display type beside a
  portrait frame.

  The CTA always links to the server-generated products path — a
  merchant-controlled href here would be a stored-XSS sink, so no URL
  setting exists. The image setting only renders local upload paths,
  mirroring Atelier's `valid_hero_image?/1`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Ntoma.Shared

  @impl true
  def key, do: "ntoma/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "Shop the collection"},
      %{key: "image_url", type: :image_url, label: "Image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    custom_headline = present(assigns.settings["headline"])

    assigns =
      assigns
      |> assign(:custom_headline, custom_headline)
      |> assign(:headline, custom_headline || assigns.store.name)
      |> assign(
        :subheadline,
        present(assigns.settings["subheadline"]) || present(assigns.store.description)
      )
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Shop the collection")
      |> assign(:image, valid_image(assigns.settings["image_url"]))

    ~H"""
    <section
      class="overflow-hidden border-b border-[#E6D5B8] bg-[#FAF4EA]"
      aria-labelledby="ntoma-hero-heading"
    >
      <div class="mx-auto max-w-[1280px] px-4 py-12 sm:px-6 sm:py-16 lg:px-8 lg:py-24">
        <div class={@image && "grid gap-10 lg:grid-cols-12 lg:items-center"}>
          <div class={@image && "lg:col-span-7"}>
            <p
              :if={@custom_headline}
              class="mb-4 text-[0.6875rem] font-bold uppercase tracking-[0.24em] text-[#B97C10]"
            >
              {@store.name}
            </p>
            <h1
              id="ntoma-hero-heading"
              class="break-words text-[clamp(2.75rem,9vw,6.5rem)] font-semibold uppercase leading-[0.92] tracking-[-0.01em] text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]"
            >
              {@headline}
            </h1>
            <Shared.woven_strip class="mt-7 h-2 max-w-[280px]" />
            <p
              :if={@subheadline}
              class="mt-6 max-w-xl text-base leading-relaxed text-[#7A6248] sm:text-lg"
            >
              {@subheadline}
            </p>
            <a
              href={store_path(@store.slug, "/products")}
              class="mt-8 inline-flex items-center gap-2.5 bg-store-accent px-8 py-4 text-sm font-bold uppercase tracking-[0.14em] leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 focus-visible:ring-offset-[#FAF4EA] motion-safe:transition-opacity motion-safe:active:scale-[0.99]"
            >
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
            </a>
          </div>
          <div :if={@image} class="lg:col-span-5">
            <.optimized_image
              src={@image}
              alt={"#{@store.name} collection"}
              priority={:high}
              width={560}
              height={700}
              class="aspect-[4/5] w-full border border-[#E6D5B8] object-cover"
            />
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

  # Local upload paths only — mirrors Atelier's valid_hero_image?/1. The
  # write path (HomeSections.sanitize_entry) already blocks non-http(s)
  # schemes for :image_url settings; this render-side gate additionally
  # keeps remote URLs out of the src position.
  defp valid_image(url) when is_binary(url) do
    if String.starts_with?(url, "/uploads/") or String.starts_with?(url, "/images/"),
      do: url,
      else: nil
  end

  defp valid_image(_url), do: nil
end
