defmodule Emakola.Themes.Heirloom.Sections.Hero do
  @moduledoc """
  Full-bleed photograph, headline over it, and a floating card for one real
  product.

  The photograph is only ever one the merchant chose. The headline reads as
  the store's own name and the supporting text as its description until the
  merchant writes their own — no line the theme wrote speaks for a store.

  Three pieces are data-dependent and each disappears on its own:

  - the room pills are the store's own categories, hidden below two (a single
    pill is a label, not a filter) and until the stall is full enough to need
    sorting (`Emakola.Themes.Layout`: four or more products)
  - the floating card is Heirloom's featured card: the catalogue's first
    product (`Layout.featured`), with its real name and its real price, which
    the showcase below then leaves out so nothing is shown twice. A
    one-product shop is carried by this card alone; a store with no products
    has no card
  - the was-price only appears when the variant genuinely carries a higher
    `compare_at_price`

  The nav is NOT rendered here. It lives in `Heirloom.Home` chrome, so
  reordering or disabling this section in the editor can never cost the
  storefront its navigation.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Heirloom.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "heirloom/hero"

  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Headline", default: ""},
      %{key: "subheading", type: :text, label: "Supporting text", default: ""},
      %{key: "cta_text", type: :string, label: "Button label", default: ""},
      %{key: "image_url", type: :image_url, label: "Background image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    store = assigns.store
    categories = Map.get(assigns, :categories) || []
    hero = get_in(assigns.theme, [:hero]) || %{}
    layout = Layout.of(assigns)

    featured = layout.featured

    assigns =
      assigns
      |> assign(:layout, layout)
      |> assign(
        :heading,
        present(assigns.settings["heading"]) || present(hero[:title]) || store.name
      )
      |> assign(
        :subheading,
        present(assigns.settings["subheading"]) || present(hero[:subtitle]) ||
          present(Map.get(store, :description)) || ""
      )
      |> assign(:cta_text, present(assigns.settings["cta_text"]) || "Shop the collection")
      |> assign(
        :image_url,
        present(assigns.settings["image_url"]) || present(hero[:image_url])
      )
      |> assign(:pills, Enum.take(categories, 4))
      |> assign(:featured, featured)
      |> assign(:featured_price, featured && Shared.price_label(featured, store))
      |> assign(:featured_compare, featured && Shared.compare_at_label(featured, store))

    ~H"""
    <section class="relative isolate min-h-[38rem] overflow-hidden bg-[color:var(--hl-tile)] lg:min-h-[46rem]">
      <img
        :if={@image_url}
        src={@image_url}
        alt=""
        loading="eager"
        fetchpriority="high"
        class="absolute inset-0 -z-10 h-full w-full object-cover"
      />
      <div
        aria-hidden="true"
        class="absolute inset-0 -z-10 bg-gradient-to-t from-black/55 via-black/20 to-black/30"
      />

      <div class="mx-auto flex min-h-[38rem] max-w-[1360px] flex-col justify-end px-5 pb-14 pt-32 sm:px-8 lg:min-h-[46rem] lg:pb-20">
        <div
          :if={length(@pills) > 1 and @layout.show_categories?}
          class="mb-8 flex flex-wrap gap-1 self-start rounded-full bg-white/15 p-1 backdrop-blur"
        >
          <a
            :for={category <- @pills}
            href={store_path(@store.slug, "/category/#{category.slug}")}
            class="min-h-[40px] rounded-full px-5 text-[11px] font-semibold uppercase tracking-[0.14em] leading-[40px] text-white first:bg-white first:text-[color:var(--hl-ink)] hover:bg-white/20"
          >
            {category.name}
          </a>
        </div>

        <div class="grid items-end gap-10 lg:grid-cols-[minmax(0,1fr)_22rem]">
          <div>
            <h1
              :if={@heading != ""}
              class="max-w-[16ch] text-4xl font-light leading-[1.05] tracking-tight text-white [font-family:var(--hl-display)] sm:text-6xl lg:text-7xl"
            >
              {@heading}
            </h1>
            <p :if={@subheading != ""} class="mt-6 max-w-md text-sm leading-relaxed text-white/80">
              {@subheading}
            </p>

            <div class="mt-9 flex flex-wrap items-center gap-4">
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex min-h-[52px] items-center rounded-full bg-white px-8 text-[11px] font-semibold uppercase tracking-[0.16em] text-[color:var(--hl-ink)] motion-safe:transition-transform hover:scale-[1.02] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2"
              >
                {@cta_text}
              </a>
              <a
                href={store_path(@store.slug, "/about")}
                class="text-[11px] font-semibold uppercase tracking-[0.16em] text-white/90 hover:text-white"
              >
                Our story
              </a>
            </div>
          </div>

          <a
            :if={@featured}
            href={store_path(@store.slug, "/products/#{@featured.slug}")}
            class="flex items-center gap-4 rounded-[28px] bg-white/85 p-4 shadow-xl backdrop-blur-md motion-safe:transition-transform hover:scale-[1.02] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
          >
            <div class="h-20 w-20 shrink-0 overflow-hidden rounded-2xl bg-[color:var(--hl-tile)]">
              <.optimized_image
                :if={hero_thumb(@featured)}
                src={hero_thumb(@featured)}
                alt=""
                width={160}
                height={160}
                class="h-full w-full object-cover"
              />
              <%!-- No photo yet: a quiet pictogram on the tile, never the
                   product's initial. --%>
              <div
                :if={!hero_thumb(@featured)}
                class="flex h-full w-full items-center justify-center"
                data-placeholder="product"
                aria-hidden="true"
              >
                <svg
                  class="h-8 w-8 text-[color:var(--hl-muted)]"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="1.5"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007z"
                  />
                </svg>
              </div>
            </div>
            <div class="min-w-0">
              <p class="truncate text-base text-[color:var(--hl-ink)] [font-family:var(--hl-display)]">
                {@featured.title}
              </p>
              <p class="mt-1.5 flex items-baseline gap-2">
                <span
                  :if={@featured_price}
                  class="text-lg font-semibold tabular-nums text-[color:var(--hl-ink)]"
                >
                  {@featured_price}
                </span>
                <s :if={@featured_compare} class="text-xs text-[color:var(--hl-muted)]">
                  <span class="sr-only">was</span>{@featured_compare}
                </s>
              </p>
            </div>
          </a>
        </div>
      </div>
    </section>
    """
  end

  defp hero_thumb(product) do
    case Map.get(product, :images) do
      [_ | _] = images ->
        image = images |> Enum.sort_by(& &1.position) |> List.first()
        image.thumbnail_url || image.url

      _none ->
        nil
    end
  end

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value) when is_binary(value), do: String.trim(value) |> nilify()
  defp present(_other), do: nil

  defp nilify(""), do: nil
  defp nilify(value), do: value
end
