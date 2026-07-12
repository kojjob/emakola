defmodule Emakola.Themes.Akwaaba.Sections.Hero do
  @moduledoc """
  Akwaaba hero — the awning.

  One big rounded orange panel with the nav floating inside it, a light serif
  headline, the merchant's photography carried large, and a proof stack that
  closes with the CTA. Carries the page's single `<h1>`.

  **Photo-fallback, not photo-required.** The image resolves: the merchant's own
  hero upload → the first product's photograph → type alone. Chale's hero was
  photo-*optional* — it showed an image only if a merchant had set one, which no
  new store ever had — so in practice every storefront opened on an empty band.
  A store with a catalogue is never a blank slab here.

  The CTA links to the server-generated products path. A merchant-controlled
  href would be a stored-XSS sink, so no URL setting exists, and the image
  setting accepts local upload paths only.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Akwaaba.Shared
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def key, do: "akwaaba/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "eyebrow", type: :string, label: "Eyebrow", default: "New season"},
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "Shop now"},
      %{key: "image_url", type: :image_url, label: "Image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    hero_product = assigns |> Map.get(:products, []) |> List.first()

    assigns =
      assigns
      |> assign(:eyebrow, present(assigns.settings["eyebrow"]) || "New season")
      |> assign(:headline, present(assigns.settings["headline"]) || assigns.store.name)
      |> assign(
        :subheadline,
        present(assigns.settings["subheadline"]) || present(assigns.store.description)
      )
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Shop now")
      |> assign(:hero_product, hero_product)
      |> assign(
        :image,
        valid_image(assigns.settings["image_url"]) ||
          (hero_product && Shared.first_image(hero_product))
      )
      |> assign(:rating, rating(Map.get(assigns, :products, [])))

    ~H"""
    <section
      class="bg-white px-3 pt-3 [font-family:var(--akwaaba-body)] sm:px-5 sm:pt-5"
      aria-labelledby="akwaaba-hero-heading"
    >
      <div class="relative overflow-hidden rounded-[2rem] bg-gradient-to-br from-[#F56A33] via-[color:var(--akwaaba-sun)] to-[#D8410F] sm:rounded-[2.5rem]">
        <%!-- Light blooming behind the type: the panel should read as lit
        canvas, not flat print. Decorative. --%>
        <div
          class="pointer-events-none absolute -left-32 -top-40 h-[32rem] w-[32rem] rounded-full bg-white/15 blur-3xl"
          aria-hidden="true"
        >
        </div>

        <%!-- pt clears the overlay nav that Home floats inside this panel. --%>
        <div class="relative grid items-center gap-10 px-6 pb-14 pt-28 sm:px-10 sm:pb-16 sm:pt-32 lg:grid-cols-[1fr_1.1fr_0.85fr] lg:gap-8 lg:px-14 lg:pb-20">
          <div>
            <p class="inline-flex items-center gap-2 rounded-full bg-white/15 px-4 py-1.5 text-[0.6875rem] font-bold uppercase tracking-[0.2em] text-white ring-1 ring-inset ring-white/25">
              <span
                class="h-1.5 w-1.5 rounded-full bg-[color:var(--akwaaba-amber)]"
                aria-hidden="true"
              >
              </span>
              {@eyebrow}
            </p>

            <h1
              id="akwaaba-hero-heading"
              class="mt-6 text-5xl font-normal leading-[1.02] tracking-tight text-white [font-family:var(--akwaaba-display)] sm:text-6xl lg:text-[4.5rem]"
            >
              {@headline}
            </h1>
          </div>

          <%!-- The photograph. With an empty catalogue this column simply does
          not render and the type holds the panel alone.

          It is ordered LAST on a phone. The photograph is ~500px tall, so
          leading with it pushes "Shop now" — the buy button — below the fold and
          under the fixed bottom bar. Most of our shoppers are on phones; the
          money button does not get to hide behind the merchandise. On a wide
          screen there is room for all three columns and the natural order
          returns. --%>
          <div :if={@image} class="relative order-3 mx-auto w-full max-w-md lg:order-2 lg:max-w-none">
            <.optimized_image
              src={@image}
              alt={(@hero_product && @hero_product.title) || @store.name}
              priority={:high}
              width={760}
              height={950}
              class="mx-auto aspect-[4/5] w-full rounded-[1.75rem] object-cover shadow-2xl"
            />

            <div
              :if={@hero_product}
              class="absolute -bottom-5 left-1/2 flex w-[min(19rem,90%)] -translate-x-1/2 items-center gap-3 rounded-2xl bg-white p-2.5 pr-4 shadow-xl"
            >
              <div class="h-12 w-12 flex-shrink-0 overflow-hidden rounded-xl bg-[#F6F4F1]">
                <.optimized_image
                  src={@image}
                  alt=""
                  width={96}
                  height={96}
                  class="h-full w-full object-cover"
                />
              </div>
              <div class="min-w-0">
                <p class="truncate text-sm font-medium text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
                  {@hero_product.title}
                </p>
                <p class="text-sm font-bold tabular-nums text-[color:var(--akwaaba-sun)]">
                  {Currency.format_price_range(
                    @hero_product.min_price,
                    @hero_product.max_price,
                    @store.currency
                  )}
                </p>
              </div>
            </div>
          </div>

          <%!-- The proof stack.

          The reference fills this corner with "4.8 (15K rating)" and a cluster
          of stranger avatars. Those are mockup fictions, and shipping them as
          theme furniture would print invented social proof on every merchant's
          storefront — a lie their customers would act on and the merchant would
          wear. So: a real rating when the store has real reviews, and otherwise
          the plain truth — the rails they actually accept. --%>
          <div class="order-2 mt-2 lg:order-3 lg:mt-0">
            <div :if={@rating} class="flex items-baseline gap-2 text-white">
              <span class="text-3xl font-semibold tabular-nums [font-family:var(--akwaaba-display)]">
                {@rating.average}
              </span>
              <span class="text-sm text-white/75">
                from {@rating.count} {if @rating.count == 1, do: "review", else: "reviews"}
              </span>
            </div>

            <p :if={@subheadline} class="mt-4 max-w-xs text-sm leading-relaxed text-white/85">
              {@subheadline}
            </p>

            <ul
              :if={is_nil(@rating)}
              class="flex flex-wrap gap-2"
              aria-label="Payment methods accepted"
            >
              <li
                :for={rail <- ["MTN MoMo", "Telecel Cash", "Visa"]}
                class="rounded-full bg-white/15 px-3 py-1.5 text-xs font-medium text-white ring-1 ring-inset ring-white/25"
              >
                {rail}
              </li>
            </ul>

            <a
              href={store_path(@store.slug, "/products")}
              class="group mt-6 inline-flex items-center gap-2.5 rounded-full bg-[color:var(--akwaaba-amber)] px-7 py-3.5 text-sm font-bold text-[color:var(--akwaaba-ink)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-[color:var(--akwaaba-sun)] motion-safe:transition-transform motion-safe:hover:-translate-y-0.5"
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
                <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12l-7.5 7.5" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # Real reviews only. No reviews, no rating — see the block comment above.
  defp rating(products) do
    rated =
      Enum.filter(products, fn p ->
        is_number(Map.get(p, :avg_rating)) and (Map.get(p, :review_count) || 0) > 0
      end)

    case rated do
      [] ->
        nil

      _ ->
        count = Enum.reduce(rated, 0, &(&2 + &1.review_count))
        weighted = Enum.reduce(rated, 0, &(&2 + &1.avg_rating * &1.review_count))

        %{average: :erlang.float_to_binary(weighted / count, decimals: 1), count: count}
    end
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil

  # Local upload paths only — a remote URL in a src position sourced from
  # merchant settings is a stored-XSS sink.
  defp valid_image(url) when is_binary(url) do
    if String.starts_with?(url, "/uploads/") or String.starts_with?(url, "/images/"),
      do: url,
      else: nil
  end

  defp valid_image(_url), do: nil
end
