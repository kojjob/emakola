defmodule Emakola.Themes.Chale.Sections.Hero do
  @moduledoc """
  Chale home hero — the poster stapled to the wall.

  Carries the page's `<h1>`. Photo-optional: with the merchant's own hero
  upload it is a split poster — display type beside a square image; without
  one it is a pure type poster, the store name at display scale in ink on
  bone, closed by the frieze. It never borrows a product photograph: the
  drop below already carries it, and a product's photo appears once on the
  page.

  The CTA always links to the server-generated products path — a
  merchant-controlled href here would be a stored-XSS sink, so no URL
  setting exists. The image setting only renders local upload paths.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  @impl true
  def key, do: "chale/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "Shop the drop"},
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
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Shop the drop")
      |> assign(:image, valid_image(assigns.settings["image_url"]))

    ~H"""
    <section class="border-b border-[#E3E0DA] bg-[#F7F5F1]" aria-labelledby="chale-hero-heading">
      <div class={[
        "mx-auto max-w-[1280px] px-4 py-12 sm:px-6 sm:py-16 lg:px-8 lg:py-20",
        @image && "grid gap-8 lg:grid-cols-2 lg:items-center lg:gap-12"
      ]}>
        <div>
          <p
            :if={@custom_headline}
            class="mb-4 inline-block bg-store-accent px-2 py-1 text-[0.6875rem] font-bold uppercase tracking-[0.25em] text-white"
          >
            {@store.name}
          </p>
          <h1
            id="chale-hero-heading"
            class="text-5xl font-bold uppercase leading-[0.95] tracking-tight text-[#101114] [font-family:var(--chale-display)] sm:text-7xl lg:text-8xl"
          >
            {@headline}
          </h1>
          <p
            :if={@subheadline}
            class="mt-5 max-w-xl text-base font-medium leading-relaxed text-zinc-600 sm:text-lg"
          >
            {@subheadline}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="group mt-8 inline-block focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2547E8] focus-visible:ring-offset-2 focus-visible:ring-offset-[#F7F5F1]"
          >
            <span class="flex items-center gap-2 rounded-xl bg-store-accent px-7 py-4 text-sm font-bold uppercase tracking-widest text-white shadow-sm motion-safe:transition-all motion-safe:hover:shadow-md motion-safe:group-hover:shadow-md motion-safe:group-hover:-translate-y-0.5 motion-safe:group-active:translate-y-0">
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
          <div class="overflow-hidden rounded-xl border border-[#E3E0DA] bg-white shadow-md">
            <.optimized_image
              src={@image}
              alt={"#{@store.name} storefront"}
              priority={:high}
              width={640}
              height={640}
              class="aspect-square w-full object-cover"
            />
          </div>
        </div>
      </div>
      <%!-- The frieze: the poster's bottom edge. It used to be a saturated
      band, which now fights the CTA for the eye — the accent is spent in one
      place. Ink on bone between hairlines, with the accent only on the mark.
      Decorative, so hidden from assistive tech. --%>
      <div
        class="overflow-hidden border-y border-[#E3E0DA] bg-white py-2.5"
        aria-hidden="true"
      >
        <p class="whitespace-nowrap text-[0.6875rem] font-semibold uppercase tracking-[0.3em] text-[#5B5750]">
          <span :for={_i <- 1..8} class="mx-3">
            {@store.name} <span class="text-store-accent">&#10022;</span> Fresh stock
          </span>
        </p>
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
