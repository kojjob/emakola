defmodule Emakola.Themes.Sika.Sections.Hero do
  @moduledoc """
  Sika home hero — the engraved title page. Carries the page's `<h1>`.

  Photo-optional by design: with no image it is a centred typographic
  composition — the display headline over the caught-light rule, with a
  pair of hairline rings (a band catching light) as the only ornament.
  With a local upload the piece sits beside the text in a vitrine mat.

  The CTA always links to the server-generated products path — a
  merchant-controlled href here would be a stored-XSS sink, so no URL
  setting exists. The image setting renders local upload paths only.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Sika.Shared

  @impl true
  def key, do: "sika/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "View the collection"},
      %{key: "image_url", type: :image_url, label: "Image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    custom_headline = Shared.present(assigns.settings["headline"])

    assigns =
      assigns
      |> assign(:custom_headline, custom_headline)
      |> assign(:headline, custom_headline || assigns.store.name)
      |> assign(
        :subheadline,
        Shared.present(assigns.settings["subheadline"]) ||
          Shared.present(assigns.store.description)
      )
      |> assign(
        :cta_label,
        Shared.present(assigns.settings["cta_label"]) || "View the collection"
      )
      |> assign(:image, valid_image(assigns.settings["image_url"]))

    ~H"""
    <section
      class="relative overflow-hidden px-4 py-16 sm:px-6 sm:py-24 lg:px-8"
      aria-labelledby="sika-hero-heading"
    >
      <div
        :if={!@image}
        class="pointer-events-none absolute -right-24 top-1/2 hidden -translate-y-1/2 select-none sm:block"
        aria-hidden="true"
      >
        <div class="h-80 w-80 rounded-full border border-[#C2A15B]/25 lg:h-[26rem] lg:w-[26rem]">
        </div>
        <div class="absolute inset-8 rounded-full border border-[#C2A15B]/15"></div>
      </div>
      <div class={[
        "relative mx-auto max-w-[1200px]",
        @image && "grid gap-10 lg:grid-cols-2 lg:items-center lg:gap-16"
      ]}>
        <div class={if(@image, do: "max-w-xl", else: "mx-auto max-w-2xl text-center")}>
          <p
            :if={@custom_headline}
            class="mb-4 text-[0.6875rem] font-semibold uppercase tracking-[0.25em] text-[#6E675C]"
          >
            {@store.name}
          </p>
          <h1
            id="sika-hero-heading"
            class="text-4xl leading-[1.08] text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)] sm:text-5xl lg:text-6xl"
          >
            {@headline}
          </h1>
          <Shared.caught_light class={["mt-6 w-16", !@image && "mx-auto"]} />
          <p :if={@subheadline} class="mt-6 text-base leading-relaxed text-[#6E675C] sm:text-lg">
            {@subheadline}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="mt-9 inline-block bg-store-accent px-9 py-4 text-[0.75rem] font-semibold uppercase tracking-[0.25em] text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-opacity"
          >
            {@cta_label}
          </a>
        </div>
        <div :if={@image} class="border border-[#E8E3D9] bg-white p-2 sm:p-3">
          <.optimized_image
            src={@image}
            alt={"#{@store.name} — featured piece"}
            priority={:high}
            width={640}
            height={640}
            class="aspect-square w-full object-cover"
          />
        </div>
      </div>
    </section>
    """
  end

  # Local upload paths only — the write path (HomeSections.sanitize_entry)
  # already blocks non-http(s) schemes for :image_url settings; this
  # render-side gate additionally keeps remote URLs out of the src position.
  defp valid_image(url) when is_binary(url) do
    if String.starts_with?(url, "/uploads/") or String.starts_with?(url, "/images/"),
      do: url,
      else: nil
  end

  defp valid_image(_url), do: nil
end
