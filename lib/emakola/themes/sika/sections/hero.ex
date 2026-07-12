defmodule Emakola.Themes.Sika.Sections.Hero do
  @moduledoc """
  Sika home hero — the vitrine. Carries the page's `<h1>`.

  The composition is the one from the reference storefront: a saturated panel
  holding the top of the page, the display headline set large, the merchant's
  photograph carried beside it with a price chip floating over its corner, and
  the buy button sitting in the proof column. Sika paints it in its own colours —
  deep malachite and caught gold, set in Marcellus — so it reads as a jeweller's
  window rather than a fashion shop.

  **Photo-fallback, not photo-optional.** The image resolves: the merchant's own
  upload → the first piece's photograph → type alone. The hero used to render an
  image only when a merchant had set one in the editor, which no new store has —
  so in practice every Sika storefront opened on an empty slab of type.

  The CTA always links to the server-generated products path: a
  merchant-controlled href would be a stored-XSS sink, so no URL setting exists,
  and the image setting still renders local upload paths only.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Sika.Shared
  alias EmakolaWeb.Helpers.Currency

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
    hero_product = assigns |> Map.get(:products, []) |> List.first()
    custom_headline = Shared.present(assigns.settings["headline"])

    assigns =
      assigns
      # When a merchant writes their own headline, the shop's name would
      # otherwise disappear from its own hero — so it takes the eyebrow.
      |> assign(:eyebrow, (custom_headline && assigns.store.name) || "The collection")
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
      |> assign(:hero_product, hero_product)
      |> assign(
        :image,
        valid_image(assigns.settings["image_url"]) ||
          (hero_product && Shared.first_image(hero_product))
      )

    ~H"""
    <section class="bg-[#FBFAF7] px-3 pt-3 sm:px-5 sm:pt-5" aria-labelledby="sika-hero-heading">
      <div class="relative overflow-hidden rounded-[1.75rem] bg-store-accent sm:rounded-[2.25rem]">
        <div
          class="pointer-events-none absolute -right-20 -top-24 h-[24rem] w-[24rem] rounded-full border border-[#C2A15B]/20"
          aria-hidden="true"
        >
        </div>

        <%!-- The pitch stands together: eyebrow, headline, the merchant's own
        words, the rails they accept and the way in — one column, read top to
        bottom. It used to be split across three, with the photograph wedged
        between the headline and its own buy button, and a third column that
        emptied out entirely on a store with no description: the rails and the
        CTA were left floating mid-air, attached to nothing. --%>
        <div class={[
          "relative grid items-center gap-10 px-6 py-14 sm:px-10 sm:py-20 lg:px-14",
          @image && "lg:grid-cols-2 lg:gap-16"
        ]}>
          <div>
            <p class="text-[0.6875rem] font-semibold uppercase tracking-[0.3em] text-[#C2A15B]">
              {@eyebrow}
            </p>

            <h1
              id="sika-hero-heading"
              class="mt-5 text-4xl leading-[1.06] text-[#F7F3EA] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)] sm:text-5xl lg:text-6xl"
            >
              {@headline}
            </h1>

            <p :if={@subheadline} class="mt-6 max-w-md leading-relaxed text-[#F7F3EA]/70">
              {@subheadline}
            </p>

            <ul class="mt-7 flex flex-wrap gap-2" aria-label="Payment methods accepted">
              <li
                :for={rail <- ["MTN MoMo", "Telecel Cash", "Visa"]}
                class="border border-[#C2A15B]/40 px-3 py-1.5 text-[0.6875rem] uppercase tracking-widest text-[#F7F3EA]/80"
              >
                {rail}
              </li>
            </ul>

            <a
              href={store_path(@store.slug, "/products")}
              class="mt-7 inline-flex items-center gap-3 bg-[#C2A15B] px-7 py-4 text-[0.6875rem] font-semibold uppercase tracking-[0.25em] text-[#1F332C] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F7F3EA] focus-visible:ring-offset-2 focus-visible:ring-offset-store-accent motion-safe:transition-opacity motion-safe:hover:opacity-90"
            >
              {@cta_label}
            </a>
          </div>

          <%!-- The vitrine. On a phone it follows the pitch, so the buy button
          is never buried under ~500px of photograph. --%>
          <div :if={@image} class="relative w-full lg:max-w-md lg:justify-self-end">
            <div class="border border-[#C2A15B]/30 p-2">
              <.optimized_image
                src={@image}
                alt={(@hero_product && @hero_product.title) || @store.name}
                priority={:high}
                width={720}
                height={900}
                class="aspect-[4/5] w-full object-cover"
              />
            </div>

            <%!-- The price tag, not a second picture: the piece is already in
            the frame it hangs off. --%>
            <div
              :if={@hero_product}
              class="absolute -bottom-4 -left-4 max-w-[14rem] border border-[#C2A15B]/40 bg-[#FBFAF7] px-5 py-3 shadow-lg"
            >
              <p class="truncate text-sm text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]">
                {@hero_product.title}
              </p>
              <p class="mt-0.5 text-sm font-semibold tabular-nums text-[#6E675C]">
                {Currency.format_price_range(
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

  # Local upload paths only — the write path already blocks non-http(s) schemes
  # for :image_url settings; this render-side gate keeps remote URLs out of the
  # src position entirely.
  defp valid_image(url) when is_binary(url) do
    if String.starts_with?(url, "/uploads/") or String.starts_with?(url, "/images/"),
      do: url,
      else: nil
  end

  defp valid_image(_url), do: nil
end
