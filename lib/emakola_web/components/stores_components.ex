defmodule EmakolaWeb.StoresComponents do
  @moduledoc """
  Components used by the public `/stores` directory.

  - `store_card/1` — primary card; cover image, logo, name, tagline,
    theme/region pill, product count, rating, "Visit shop" CTA, ♡ button.
  - `filter_chips/1` — theme filter chips (All + one chip per registered theme).
  - `region_filter/1` — dropdown for Ghana regions.
  - `sort_dropdown/1` — Newest / A-Z / Most popular / Featured.
  - `featured_spotlight/1` — the big hero plus the also-featured photo tiles.
  - `recently_viewed_strip/1` — 6-up horizontal strip from cookie.
  - `map_view/1` — Ghana SVG with regional pins (Phase 3).
  """

  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.ThemeResolver
  alias EmakolaWeb.Helpers.CssColor

  @regions [
    {"", "All regions"},
    {"greater_accra", "Greater Accra"},
    {"ashanti", "Ashanti"},
    {"central", "Central"},
    {"western", "Western"},
    {"eastern", "Eastern"},
    {"northern", "Northern"},
    {"volta", "Volta"},
    {"other", "Other"}
  ]

  @sorts [
    {"featured", "Featured"},
    {"newest", "Newest"},
    {"popular", "Most popular"},
    {"name", "A → Z"}
  ]

  # Approximate (x, y) coordinates for each region pin within the
  # `viewBox 0 0 400 500` Ghana outline used by `map_view/1`. Not
  # cartographically precise — placed where a Ghanaian user would
  # expect each region to sit on a familiar outline.
  @region_pins %{
    "northern" => {200, 110},
    "ashanti" => {185, 295},
    "volta" => {305, 305},
    "eastern" => {255, 360},
    "western" => {135, 390},
    "central" => {200, 420},
    "greater_accra" => {275, 425},
    "other" => {140, 205}
  }

  @doc "Curated Ghana regions formatted as select options."
  def regions, do: Enum.map(@regions, fn {value, label} -> {label, value} end)

  @doc "Sort dropdown options formatted as select options."
  def sorts, do: Enum.map(@sorts, fn {value, label} -> {label, value} end)

  # ── Store card (default variant) ──

  attr :id, :string, default: nil
  attr :store, :map, required: true
  attr :is_favorite, :boolean, default: false
  attr :variant, :atom, default: :default, values: [:default, :featured, :editorial, :compact]
  # Admin embeds (the Directory Studio preview) open the storefront in a new
  # tab and hide the customer-only favorite button.
  attr :target, :string, default: nil
  attr :show_favorite, :boolean, default: true

  def store_card(assigns) do
    ~H"""
    <article
      id={@id}
      class={[
        "group relative flex min-w-0 flex-col overflow-hidden rounded-[1.75rem] border border-slate-200 bg-white shadow-[0_10px_35px_-28px_rgba(12,31,23,0.55)] transition duration-300 hover:-translate-y-1 hover:border-amber-400/60 hover:shadow-[0_22px_55px_-28px_rgba(12,31,23,0.4)]",
        card_variant_class(@variant)
      ]}
    >
      <a
        href={EmakolaWeb.Storefront.Path.public_path(@store.slug)}
        target={@target}
        rel={@target == "_blank" && "noopener"}
        class="relative block aspect-[16/10] overflow-hidden bg-slate-200"
      >
        <%= if card_image_url(@store) do %>
          <.optimized_image
            src={card_image_url(@store)}
            alt={"#{@store.name} shop photo"}
            class="absolute inset-0 h-full w-full object-cover transition duration-700 group-hover:scale-105"
          />
        <% else %>
          <div
            class="stores-card-pattern absolute inset-0 bg-[linear-gradient(135deg,var(--color-store-accent),var(--color-cta-dark))]"
            style={card_theme_vars(@store)}
          >
          </div>
          <div class="absolute inset-0 flex items-center justify-center text-white/25">
            <.icon
              name="hero-building-storefront"
              class="size-20 transition duration-500 group-hover:scale-110"
            />
          </div>
        <% end %>

        <div class="absolute inset-0 bg-gradient-to-t from-slate-950/65 via-transparent to-black/10">
        </div>

        <div class="absolute left-3 top-3 flex flex-wrap items-center gap-2">
          <span
            :if={Map.get(@store, :featured)}
            class="inline-flex items-center gap-1 rounded-full bg-amber-300 px-2.5 py-1 text-[10px] font-black uppercase tracking-[0.12em] text-emerald-950 shadow-sm"
          >
            <.icon name="hero-star-solid" class="size-3" /> Featured
          </span>
          <span
            :if={Map.get(@store, :verified)}
            class="inline-flex items-center gap-1 rounded-full bg-white/95 px-2.5 py-1 text-[10px] font-black uppercase tracking-[0.12em] text-emerald-800 shadow-sm backdrop-blur"
            title="Verified merchant"
          >
            <.icon name="hero-check-badge-solid" class="size-3.5" /> Verified
          </span>
        </div>

        <div class="absolute bottom-4 left-4 right-4 flex items-end justify-between gap-3">
          <div class="flex min-w-0 items-end gap-3">
            <div class="flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-2xl border-[3px] border-white bg-white shadow-lg">
              <%= if @store.logo_url && @store.logo_url != "" do %>
                <img
                  src={@store.logo_url}
                  alt={"#{@store.name} logo"}
                  class="h-full w-full object-cover"
                  loading="lazy"
                />
              <% else %>
                <span
                  class="text-lg font-black text-store-accent"
                  style={card_theme_vars(@store)}
                >
                  {String.first(@store.name) |> String.upcase()}
                </span>
              <% end %>
            </div>
            <span class="mb-0.5 truncate text-xs font-bold uppercase tracking-[0.14em] text-white/80">
              {theme_label(@store)}
            </span>
          </div>

          <span class="flex size-9 shrink-0 items-center justify-center rounded-full bg-white/95 text-slate-900 shadow-md transition group-hover:bg-amber-300">
            <.icon name="hero-arrow-up-right" class="size-4" />
          </span>
        </div>
      </a>

      <div class="flex flex-1 flex-col px-5 pb-5 pt-5">
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <a
              href={EmakolaWeb.Storefront.Path.public_path(@store.slug)}
              target={@target}
              rel={@target == "_blank" && "noopener"}
              class="line-clamp-1 text-lg font-black tracking-tight text-slate-900 transition hover:text-emerald-700"
            >
              {@store.name}
            </a>
            <p
              :if={Map.get(@store, :tagline) && @store.tagline != ""}
              class="mt-1 line-clamp-2 min-h-10 text-sm leading-5 text-slate-600"
            >
              {@store.tagline}
            </p>
            <p
              :if={(!Map.get(@store, :tagline) || @store.tagline == "") && @store.description}
              class="mt-1 line-clamp-2 min-h-10 text-sm leading-5 text-slate-600"
            >
              {@store.description}
            </p>
            <p
              :if={
                (!Map.get(@store, :tagline) || @store.tagline == "") &&
                  (!Map.get(@store, :description) || @store.description == "")
              }
              class="mt-1 min-h-10 text-sm leading-5 text-slate-500"
            >
              Independent shop on Makola
            </p>
          </div>

          <button
            :if={@show_favorite}
            type="button"
            phx-click="toggle_favorite"
            phx-value-slug={@store.slug}
            class={[
              "flex size-10 shrink-0 items-center justify-center rounded-xl border transition",
              if(@is_favorite,
                do: "border-rose-200 bg-rose-50 text-rose-600",
                else:
                  "border-slate-200 bg-white text-slate-400 hover:border-rose-200 hover:bg-rose-50 hover:text-rose-500"
              )
            ]}
            aria-label={if @is_favorite, do: "Unsave store", else: "Save store"}
            aria-pressed={to_string(@is_favorite)}
          >
            <.icon
              name={if @is_favorite, do: "hero-heart-solid", else: "hero-heart"}
              class="size-5"
            />
          </button>
        </div>

        <div class="mt-4 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-slate-100 pt-4 text-xs font-semibold text-slate-500">
          <span :if={location(@store) != ""} class="inline-flex min-w-0 items-center gap-1.5">
            <.icon name="hero-map-pin" class="size-4 shrink-0 text-emerald-700" />
            <span class="truncate">{location(@store)}</span>
          </span>

          <span :if={tenure(@store) != ""} class="inline-flex items-center gap-1.5">
            <.icon name="hero-calendar" class="size-4 shrink-0 text-slate-400" />
            {tenure(@store)}
          </span>

          <span :if={product_count(@store) > 0} class="inline-flex items-center gap-1.5">
            <.icon name="hero-shopping-bag" class="size-4 text-amber-700" />
            {product_count(@store)} {if product_count(@store) == 1, do: "product", else: "products"}
          </span>

          <a
            href={EmakolaWeb.Storefront.Path.public_path(@store.slug)}
            class="ml-auto inline-flex items-center gap-1 font-bold text-emerald-700 transition group-hover:gap-1.5"
          >
            Visit shop <.icon name="hero-arrow-right" class="size-3.5" />
          </a>
        </div>
      </div>
    </article>
    """
  end

  defp card_variant_class(:featured), do: "lg:col-span-2"
  defp card_variant_class(:editorial), do: "bg-slate-900 text-white border-slate-800"
  defp card_variant_class(:compact), do: ""
  defp card_variant_class(_), do: ""

  # ── Featured spotlight (hero + photo tiles) ──
  #
  # Pattern A from the approved stores redesign: rank one holds a big 3:2
  # hero, the next few featured shops sit beside it as photo tiles. Nobody
  # has to swipe to be seen, and the hero stays the loudest thing in the
  # row because only one shop ever holds it.

  attr :hero, :map, required: true
  attr :tiles, :list, default: []

  def featured_spotlight(assigns) do
    ~H"""
    <section id="featured-spotlight" class="border-b border-slate-200 bg-white py-12 sm:py-16">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between gap-5">
          <div>
            <p class="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.2em] text-amber-700">
              <.icon name="hero-star-solid" class="size-4" /> Market spotlight
            </p>
            <h2 class="mt-2 font-headline text-3xl font-black tracking-tight text-slate-900 sm:text-4xl">
              Shops people should know
            </h2>
          </div>
          <a
            href="#main-grid"
            class="hidden items-center gap-2 text-sm font-bold text-emerald-700 transition hover:gap-2.5 sm:inline-flex"
          >
            Browse all <.icon name="hero-arrow-down" class="size-4" />
          </a>
        </div>

        <div class="mt-7 grid gap-6 lg:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
          <a
            id="featured-hero"
            href={EmakolaWeb.Storefront.Path.public_path(@hero.slug)}
            class="group relative block overflow-hidden rounded-[1.75rem] bg-slate-900 shadow-[0_32px_64px_-36px_rgba(12,31,23,0.55)]"
          >
            <div class="relative aspect-[4/5] sm:aspect-[3/2]">
              <%!-- The LCP element: lazy-loading it cost 10s of LCP on 4G. --%>
              <.optimized_image
                src={card_image_url(@hero)}
                alt={"#{@hero.name} shop photo"}
                priority={:high}
                class="absolute inset-0 h-full w-full object-cover transition duration-700 group-hover:scale-105"
              />
              <div class="absolute inset-0 bg-gradient-to-t from-slate-950/95 via-slate-950/30 to-black/5">
              </div>

              <div class="absolute left-5 top-5 flex flex-wrap gap-2">
                <span class="inline-flex items-center gap-1 rounded-full bg-amber-300 px-3 py-1.5 text-[10px] font-black uppercase tracking-[0.13em] text-emerald-950">
                  <.icon name="hero-star-solid" class="size-3" /> Featured
                </span>
                <span
                  :if={Map.get(@hero, :verified)}
                  class="inline-flex items-center gap-1 rounded-full bg-white/95 px-3 py-1.5 text-[10px] font-black uppercase tracking-[0.13em] text-emerald-800"
                >
                  <.icon name="hero-check-badge-solid" class="size-3.5" /> Verified
                </span>
              </div>

              <div class="absolute inset-x-5 bottom-5 flex flex-col items-start gap-3 sm:inset-x-8 sm:bottom-7 sm:flex-row sm:items-end sm:justify-between sm:gap-7">
                <div class="min-w-0">
                  <p class="text-xs font-bold uppercase tracking-[0.16em] text-white/80">
                    {theme_label(@hero)}
                    <span :if={location(@hero) != ""}>&middot; {location(@hero)}</span>
                    <span :if={product_count(@hero) > 0}>
                      &middot; {product_count(@hero)} {if product_count(@hero) == 1,
                        do: "product",
                        else: "products"}
                    </span>
                  </p>
                  <p class="mt-2 font-headline text-3xl font-black leading-[1.05] tracking-tight text-white sm:text-5xl">
                    {@hero.name}
                  </p>
                  <p
                    :if={Map.get(@hero, :tagline) && @hero.tagline != ""}
                    class="mt-2 line-clamp-2 max-w-md text-base text-white/90 sm:text-lg"
                  >
                    {@hero.tagline}
                  </p>
                </div>
                <span class="inline-flex shrink-0 items-center gap-2 rounded-xl bg-[#d4a843] px-6 py-3.5 text-base font-bold text-emerald-950 transition group-hover:bg-amber-300">
                  Visit shop <.icon name="hero-arrow-right" class="size-4" />
                </span>
              </div>
            </div>
          </a>

          <div class="flex flex-col gap-3.5 rounded-[1.75rem] border border-slate-200 bg-white p-5 sm:p-6">
            <div class="flex items-center justify-between">
              <p class="text-xs font-bold uppercase tracking-[0.14em] text-slate-500">
                Also featured
              </p>
              <a href="#main-grid" class="text-sm font-bold text-emerald-700">
                See all <.icon name="hero-arrow-down" class="inline size-3.5" />
              </a>
            </div>

            <div id="featured-tiles" class="grid flex-1 grid-cols-2 gap-3">
              <a
                :for={store <- @tiles}
                href={EmakolaWeb.Storefront.Path.public_path(store.slug)}
                class="group relative block overflow-hidden rounded-2xl bg-slate-200"
              >
                <div class="relative aspect-square">
                  <.optimized_image
                    src={card_image_url(store)}
                    alt={"#{store.name} shop photo"}
                    class="absolute inset-0 h-full w-full object-cover transition duration-700 group-hover:scale-105"
                  />
                  <div class="absolute inset-0 bg-gradient-to-t from-slate-950/90 via-slate-950/10 to-transparent">
                  </div>
                  <div class="absolute inset-x-3.5 bottom-3">
                    <p class="line-clamp-1 text-base font-black tracking-tight text-white">
                      {store.name}
                    </p>
                    <p class="mt-0.5 line-clamp-1 text-[10px] font-bold uppercase tracking-[0.1em] text-white/75">
                      {theme_label(store)}
                      <span :if={location(store) != ""}>&middot; {location(store)}</span>
                    </p>
                  </div>
                </div>
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ── New-on-Makola strip (compact horizontal) ──

  attr :stores, :list, required: true
  attr :title, :string, default: "New on Makola"
  attr :subtitle, :string, default: "Just joined the marketplace"

  attr :id_prefix, :string,
    default: "recent",
    doc: "namespaces the strip's SVG pattern ids — several strips now share one page"

  def recent_strip(assigns) do
    ~H"""
    <section :if={@stores != []}>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="flex items-end justify-between gap-4 mb-7 flex-wrap">
          <div class="flex items-center gap-4">
            <%!--
              Custom inline SVG: layered sparkle on a soft gradient tile.
              Better than the Material `auto_awesome` glyph because the
              strokes are tuned for the size, the gradient ties the icon
              to the section's emerald accent, and it scales sharp at any
              DPI without the icon-font flash-of-unstyled-text problem.
            --%>
            <span class="hidden sm:flex w-14 h-14 rounded-2xl items-center justify-center shrink-0 shadow-[0_8px_24px_-12px_rgba(16,185,129,0.45)] bg-gradient-to-br from-emerald-400 via-emerald-500 to-teal-600">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 32 32"
                class="w-8 h-8 text-white"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M19.5 4a1 1 0 0 1 .96.72l1.27 4.32 4.55 1.34a1 1 0 0 1 0 1.92l-4.55 1.34-1.27 4.32a1 1 0 0 1-1.92 0L17.27 13.64 12.72 12.3a1 1 0 0 1 0-1.92l4.55-1.34L18.54 4.72A1 1 0 0 1 19.5 4Zm-9 9a1 1 0 0 1 .96.72l.83 2.85 2.93.86a1 1 0 0 1 0 1.92l-2.93.86-.83 2.85a1 1 0 0 1-1.92 0l-.83-2.85-2.93-.86a1 1 0 0 1 0-1.92l2.93-.86.83-2.85A1 1 0 0 1 10.5 13Zm12.18 8.05a1 1 0 0 1 1.86 0l.4 1.07 1.06.4a1 1 0 0 1 0 1.86l-1.06.4-.4 1.07a1 1 0 0 1-1.86 0l-.4-1.07-1.06-.4a1 1 0 0 1 0-1.86l1.06-.4.4-1.07Z"
                  clip-rule="evenodd"
                />
              </svg>
            </span>
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-emerald-700">
                Fresh arrivals
              </p>
              <h2 class="text-2xl sm:text-3xl font-bold text-slate-900 mt-0.5">
                {@title}
              </h2>
              <p class="text-sm text-slate-500 mt-0.5">{@subtitle}</p>
            </div>
          </div>
          <a
            href="#main-grid"
            class="hidden sm:inline-flex items-center gap-1.5 text-sm font-semibold text-slate-700 hover:text-emerald-700 transition-colors group"
          >
            View all stores
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="w-4 h-4 group-hover:translate-x-0.5 transition-transform"
            >
              <path d="M5 12h14M13 5l7 7-7 7" />
            </svg>
          </a>
        </div>

        <%!--
          Flex-wrap layout instead of rigid grid: cards keep a consistent
          width but flow naturally so 1-2 stores look intentional rather
          than leaving 4 empty grid cells. Mobile gets horizontal scroll.
        --%>
        <div class="overflow-x-auto -mx-4 sm:mx-0 px-4 sm:px-0 scrollbar-hide pb-3">
          <div class="flex flex-nowrap sm:flex-wrap gap-5 sm:gap-6 min-w-max sm:min-w-0">
            <%!--
              Magazine-style card: image hero on top with overlay name +
              floating logo, then a clean meta row. Explicit h-48
              (192px) on the image area instead of arbitrary aspect
              ratios so it renders consistently in dev and prod builds.
            --%>
            <a
              :for={store <- @stores}
              href={EmakolaWeb.Storefront.Path.public_path(store.slug)}
              class="group block w-[260px] sm:w-[290px] shrink-0 bg-white rounded-3xl overflow-hidden ring-1 ring-slate-200 hover:ring-2 hover:ring-emerald-300 shadow-sm hover:shadow-2xl hover:shadow-emerald-500/15 hover:-translate-y-1 transition-all duration-300"
            >
              <%!-- IMAGE HERO --%>
              <div class="relative h-48 w-full overflow-hidden bg-slate-100">
                <%= if card_image_url(store) do %>
                  <.optimized_image
                    src={card_image_url(store)}
                    alt={"#{store.name} shop photo"}
                    class="absolute inset-0 w-full h-full object-cover group-hover:scale-110 transition-transform duration-700"
                  />
                <% else %>
                  <div
                    class="absolute inset-0 bg-[linear-gradient(135deg,var(--color-store-accent),var(--color-cta-dark))]"
                    style={card_theme_vars(store)}
                  >
                  </div>
                  <%!-- Texture: diagonal lines for richer fallback --%>
                  <svg
                    class="absolute inset-0 w-full h-full opacity-20 mix-blend-overlay"
                    xmlns="http://www.w3.org/2000/svg"
                    aria-hidden="true"
                  >
                    <defs>
                      <pattern
                        id={"diag-#{@id_prefix}-#{store.slug}"}
                        width="14"
                        height="14"
                        patternUnits="userSpaceOnUse"
                        patternTransform="rotate(45)"
                      >
                        <line x1="0" y="0" x2="0" y2="14" stroke="white" stroke-width="2" />
                      </pattern>
                    </defs>
                    <rect
                      width="100%"
                      height="100%"
                      fill={"url(##{"diag-" <> @id_prefix <> "-" <> store.slug})"}
                    />
                  </svg>
                  <%!-- Centered storefront mark --%>
                  <div class="absolute inset-0 flex items-center justify-center">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 64 64"
                      class="w-20 h-20 text-white/40"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      aria-hidden="true"
                    >
                      <path d="M8 22h48l-4-10H12L8 22z" />
                      <path d="M12 22v28a4 4 0 0 0 4 4h32a4 4 0 0 0 4-4V22" />
                      <path d="M24 54V36h16v18" />
                      <path d="M8 22a8 8 0 0 0 16 0M24 22a8 8 0 0 0 16 0M40 22a8 8 0 0 0 16 0" />
                    </svg>
                  </div>
                <% end %>

                <%!-- Strong top→bottom gradient so name+logo stay legible --%>
                <div class="absolute inset-0 bg-gradient-to-t from-black/75 via-black/20 to-black/30 pointer-events-none">
                </div>

                <%!-- NEW pill (top-left) --%>
                <span class="absolute top-3 left-3 inline-flex items-center gap-1.5 pl-2 pr-3 py-1 rounded-full bg-gradient-to-r from-emerald-500 to-teal-500 text-white text-[10px] font-black uppercase tracking-[0.12em] shadow-lg shadow-emerald-500/40 ring-1 ring-white/20">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 16 16"
                    class="w-3.5 h-3.5"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path d="M8 0 9.5 5 14.5 6 10.5 9.5 11.5 14.5 8 12 4.5 14.5 5.5 9.5 1.5 6 6.5 5 8 0Z" />
                  </svg>
                  New
                </span>

                <%!-- Verified badge (top-right) --%>
                <span
                  :if={Map.get(store, :verified)}
                  class="absolute top-3 right-3 inline-flex items-center justify-center w-7 h-7 rounded-full bg-sky-500 text-white shadow-md ring-2 ring-white/50"
                  title="Verified merchant"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-4 h-4"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M8.6 2.5a3 3 0 0 1 4.8 0 3 3 0 0 1 3.4 1.4 3 3 0 0 1 2.7 2.7 3 3 0 0 1 1.4 3.4 3 3 0 0 1 0 4.8 3 3 0 0 1-1.4 3.4 3 3 0 0 1-2.7 2.7 3 3 0 0 1-3.4 1.4 3 3 0 0 1-4.8 0 3 3 0 0 1-3.4-1.4 3 3 0 0 1-2.7-2.7 3 3 0 0 1-1.4-3.4 3 3 0 0 1 0-4.8 3 3 0 0 1 1.4-3.4 3 3 0 0 1 2.7-2.7A3 3 0 0 1 8.6 2.5Zm7.7 6.7a1 1 0 0 0-1.4-1.4l-4.4 4.4-1.7-1.7a1 1 0 1 0-1.4 1.4l2.4 2.4a1 1 0 0 0 1.4 0l5.1-5.1Z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </span>

                <%!-- Floating shop logo (bottom-left, overlapping) --%>
                <div class="absolute -bottom-7 left-4 z-10">
                  <%= if store.logo_url && store.logo_url != "" do %>
                    <img
                      src={store.logo_url}
                      alt={"#{store.name} logo"}
                      class="w-14 h-14 rounded-2xl ring-4 ring-white shadow-xl object-cover bg-white"
                      loading="lazy"
                    />
                  <% else %>
                    <div
                      class="w-14 h-14 rounded-2xl ring-4 ring-white shadow-xl flex items-center justify-center bg-[linear-gradient(135deg,var(--color-store-accent),var(--color-cta-dark))]"
                      style={card_theme_vars(store)}
                    >
                      <span class="text-xl font-black text-white drop-shadow-sm">
                        {String.first(store.name) |> String.upcase()}
                      </span>
                    </div>
                  <% end %>
                </div>

                <%!-- Store name overlaid on the image (right of logo) --%>
                <div class="absolute bottom-3 left-24 right-4">
                  <p class="text-white text-base font-bold drop-shadow-md line-clamp-1">
                    {store.name}
                  </p>
                  <p class="text-white/85 text-[11px] font-medium uppercase tracking-wider line-clamp-1 drop-shadow">
                    {theme_label(store)}
                  </p>
                </div>
              </div>

              <%!-- META FOOTER (below image, with extra top padding for floating logo) --%>
              <div class="px-4 pt-10 pb-4 flex items-center justify-between gap-2 text-xs">
                <div
                  :if={location(store) != ""}
                  class="flex items-center gap-1.5 min-w-0 text-slate-500"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-3.5 h-3.5 text-slate-400 shrink-0"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M11.5 22.4a.75.75 0 0 0 1 0c4.5-3.5 8-7.2 8-12.1A8.5 8.5 0 0 0 12 1.75a8.5 8.5 0 0 0-8.5 8.55c0 4.9 3.5 8.6 8 12.1ZM12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  <span class="truncate font-medium text-slate-700">{location(store)}</span>
                </div>
                <span :if={location(store) == ""} class="text-slate-500 italic">
                  Just opened
                </span>
                <span class="inline-flex items-center gap-1 text-emerald-700 font-bold whitespace-nowrap group-hover:gap-1.5 transition-all">
                  Visit
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-3.5 h-3.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M5 12h14M13 5l7 7-7 7" />
                  </svg>
                </span>
              </div>
            </a>

            <%!--
              Final CTA card. Always rendered so the strip never looks
              empty — fills the trailing whitespace when there are fewer
              stores than columns and gives users a path to the full grid.
            --%>
            <a
              href="#main-grid"
              class="group block w-[260px] sm:w-[290px] shrink-0 rounded-3xl border-2 border-dashed border-slate-300 hover:border-emerald-400 bg-gradient-to-br from-slate-50 to-emerald-50/30 hover:from-emerald-50/40 hover:to-emerald-100/30 transition-all hover:-translate-y-1"
            >
              <div class="flex flex-col items-center justify-center text-center px-6 py-12 h-full">
                <span class="w-16 h-16 rounded-2xl bg-white ring-1 ring-slate-200 group-hover:ring-emerald-300 flex items-center justify-center shadow-md transition-all group-hover:scale-105">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-8 h-8 text-emerald-600"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.8"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <circle cx="11" cy="11" r="7" />
                    <path d="m21 21-4.3-4.3" />
                  </svg>
                </span>
                <p class="text-lg font-bold text-slate-900 mt-5 group-hover:text-emerald-700 transition-colors">
                  Explore all stores
                </p>
                <p class="text-sm text-slate-500 mt-1.5">
                  Browse the full marketplace
                </p>
                <span class="inline-flex items-center gap-1.5 text-emerald-700 font-bold text-sm mt-5 group-hover:gap-2 transition-all">
                  View directory
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M5 12h14M13 5l7 7-7 7" />
                  </svg>
                </span>
              </div>
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ── Editor's picks (dark editorial cards) ──

  attr :stores, :list, required: true

  def editor_picks(assigns) do
    ~H"""
    <section :if={@stores != []} class="bg-slate-900 text-white">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="flex items-end justify-between gap-3 mb-6">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-amber-400">
              Editor's picks
            </p>
            <h2 class="text-2xl sm:text-3xl font-bold mt-1">
              Curated for the way you shop
            </h2>
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          <a
            :for={store <- @stores}
            href={EmakolaWeb.Storefront.Path.public_path(store.slug)}
            class="group relative bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 rounded-2xl overflow-hidden transition-all flex flex-col"
          >
            <div class="relative aspect-[16/9] overflow-hidden">
              <%= if store.cover_image_url && store.cover_image_url != "" do %>
                <.optimized_image
                  src={store.cover_image_url}
                  alt={"#{store.name}"}
                  class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                />
              <% else %>
                <div
                  class="absolute inset-0 bg-[linear-gradient(135deg,var(--color-store-accent),var(--color-cta-dark))]"
                  style={card_theme_vars(store)}
                >
                </div>
              <% end %>
              <div class="absolute inset-0 bg-gradient-to-t from-slate-900/80 to-transparent"></div>

              <%!-- Rank badge (1-6) --%>
              <span
                :if={Map.get(store, :featured_rank)}
                class="absolute top-3 left-3 inline-flex items-center justify-center w-8 h-8 rounded-full bg-amber-400 text-amber-950 text-sm font-black"
              >
                {store.featured_rank}
              </span>
            </div>

            <div class="p-5 flex-1 flex flex-col">
              <p class="text-base font-bold line-clamp-1 group-hover:text-amber-300 transition-colors">
                {store.name}
              </p>
              <p
                :if={Map.get(store, :tagline) && store.tagline != ""}
                class="text-sm text-white/80 mt-1.5 italic line-clamp-2"
              >
                "{store.tagline}"
              </p>
              <p
                :if={(!Map.get(store, :tagline) || store.tagline == "") && store.description}
                class="text-sm text-white/70 mt-1.5 line-clamp-2"
              >
                {store.description}
              </p>

              <div class="flex items-center gap-2 mt-4 pt-4 border-t border-white/10 text-xs text-white/60">
                <span class="inline-flex items-center gap-1">
                  <span class="material-symbols-outlined" style="font-size: 12px;">
                    location_on
                  </span>
                  {location(store)}
                </span>
                <span class="ml-auto inline-flex items-center gap-1 text-amber-300 font-semibold">
                  Visit shop
                  <span class="material-symbols-outlined" style="font-size: 14px;">
                    arrow_forward
                  </span>
                </span>
              </div>
            </div>
          </a>
        </div>
      </div>
    </section>
    """
  end

  # ── Filter chips (theme) ──

  attr :active_theme, :string, default: "all"
  attr :counts, :map, default: %{}

  def filter_chips(assigns) do
    chips = [{"all", "All shops", "hero-squares-2x2"}] ++ theme_chips()
    assigns = assign(assigns, :chips, chips)

    ~H"""
    <div class="flex min-w-max items-center gap-2" role="group" aria-label="Shop categories">
      <button
        :for={{value, label, icon} <- @chips}
        id={"theme-filter-#{value}"}
        type="button"
        phx-click="select_theme"
        phx-value-theme={value}
        aria-pressed={to_string(@active_theme == value)}
        class={[
          "inline-flex h-10 shrink-0 items-center gap-2 rounded-xl px-3.5 text-xs font-bold transition sm:px-4",
          if(@active_theme == value,
            do: "bg-slate-900 text-white shadow-sm",
            else:
              "border border-slate-200 bg-slate-50 text-slate-600 hover:border-emerald-600/40 hover:bg-emerald-50 hover:text-emerald-800"
          )
        ]}
      >
        <.icon name={icon} class="size-4" />
        {label}
        <span
          :if={(c = Map.get(@counts, value)) && c > 0}
          class={[
            "inline-flex min-w-5 items-center justify-center rounded-full px-1.5 py-0.5 text-[10px] font-black",
            if(@active_theme == value, do: "bg-white/15 text-white", else: "bg-white text-slate-500")
          ]}
        >
          {c}
        </span>
      </button>
    </div>
    """
  end

  # Each registered theme becomes a chip. Order is intentional.
  defp theme_chips do
    [
      {"market", "Market", "hero-building-storefront"},
      {"atelier", "Atelier", "hero-sparkles"},
      {"vibrant", "Vibrant", "hero-swatch"},
      {"starter", "Starter", "hero-bolt"},
      {"bold", "Bold", "hero-newspaper"},
      {"fresh", "Fresh", "hero-leaf"},
      {"pharmacy", "Pharmacy", "hero-plus-circle"},
      {"beauty", "Beauty", "hero-heart"},
      {"home_living", "Home Living", "hero-home-modern"},
      {"electronics", "Electronics", "hero-device-phone-mobile"},
      {"fashion", "Fashion", "hero-shopping-bag"}
    ]
  end

  # ── Region filter ──

  attr :active_region, :string, default: ""

  def region_filter(assigns) do
    assigns = assign(assigns, :regions, @regions)

    ~H"""
    <div class="relative">
      <select
        phx-change="select_region"
        name="region"
        class="appearance-none pl-9 pr-9 py-2 rounded-full border border-slate-200 bg-white text-xs font-semibold text-slate-700 cursor-pointer hover:border-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500"
      >
        <option :for={{value, label} <- @regions} value={value} selected={@active_region == value}>
          {label}
        </option>
      </select>
      <span
        class="material-symbols-outlined absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
        style="font-size: 16px;"
      >
        location_on
      </span>
      <span
        class="material-symbols-outlined absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
        style="font-size: 16px;"
      >
        expand_more
      </span>
    </div>
    """
  end

  # ── Sort dropdown ──

  attr :active_sort, :string, default: "featured"

  def sort_dropdown(assigns) do
    assigns = assign(assigns, :sorts, @sorts)

    ~H"""
    <div class="relative">
      <select
        phx-change="select_sort"
        name="sort"
        class="appearance-none pl-9 pr-9 py-2 rounded-full border border-slate-200 bg-white text-xs font-semibold text-slate-700 cursor-pointer hover:border-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500"
      >
        <option :for={{value, label} <- @sorts} value={value} selected={@active_sort == value}>
          Sort: {label}
        </option>
      </select>
      <span
        class="material-symbols-outlined absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
        style="font-size: 16px;"
      >
        sort
      </span>
      <span
        class="material-symbols-outlined absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
        style="font-size: 16px;"
      >
        expand_more
      </span>
    </div>
    """
  end

  # ── Helpers ──

  # "Since Mar 2026" from the store's own age. Longevity is the one trust
  # signal a fly-by-night seller cannot fake quickly, so it earns a place on
  # every card — as a number and a word, not a sentence, for readers who
  # decode symbols faster than prose.
  defp tenure(store) do
    case Map.get(store, :inserted_at) do
      %{year: _} = stamp -> "Since " <> Calendar.strftime(stamp, "%b %Y")
      _missing -> ""
    end
  end

  defp location(store) do
    [Map.get(store, :city), region_label(Map.get(store, :region))]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end

  defp region_label(nil), do: nil

  defp region_label(slug) when is_binary(slug) do
    case Enum.find(@regions, fn {value, _label} -> value == slug end) do
      {_, label} -> label
      nil -> slug
    end
  end

  defp product_count(store) do
    case Map.get(store, :product_count) do
      n when is_integer(n) -> n
      _ -> 0
    end
  end

  defp theme_label(store) do
    id = theme_id(store)

    Enum.find_value(theme_chips(), "Store", fn {chip_id, label, _icon} ->
      if chip_id == id, do: label
    end)
  end

  defp theme_id(store) do
    case Map.get(store, :theme_config) do
      %{"theme" => id} when is_binary(id) -> id
      _ -> "market"
    end
  end

  defp theme_primary(store) do
    resolve_color(theme_id(store), :primary, "#1F2937")
  end

  defp theme_accent(store) do
    resolve_color(theme_id(store), :accent, "#0EA5E9")
  end

  # Scopes the store's theme colors onto a single card element so the
  # `--color-store-accent` / `--color-cta-dark` utilities resolve per-card.
  # Setting the color tokens directly is the simplest override: inline
  # style declarations are unlayered, so they beat the `@layer theme`
  # :root token declarations for this element and its descendants.
  # The image a shop card leads with: the merchant's own cover when they set
  # one, else the newest active-product photo (the :card_image_url aggregate —
  # guard on is_binary because callers that don't load it get %Ash.NotLoaded{}),
  # else nil and the themed gradient pattern renders.
  defp card_image_url(store) do
    cover = Map.get(store, :cover_image_url)
    product_photo = Map.get(store, :card_image_url)

    cond do
      is_binary(cover) and cover != "" -> cover
      is_binary(product_photo) and product_photo != "" -> product_photo
      true -> nil
    end
  end

  defp card_theme_vars(store) do
    "--color-store-accent: #{CssColor.safe_css_color(theme_primary(store), "#B45309")}; " <>
      "--color-cta-dark: #{CssColor.safe_css_color(theme_accent(store), "#1C1917")}"
  end

  defp resolve_color(theme_id, key, fallback) do
    module = ThemeResolver.theme_module(theme_id)

    if function_exported?(module, :defaults, 0) do
      get_in(module.defaults(), [:colors, key]) || fallback
    else
      fallback
    end
  rescue
    _ -> fallback
  end

  # ── Ghana map_view modal (Phase 3) ──
  #
  # Modal that lets shoppers browse stores by Ghanaian region. Renders a
  # backdrop overlay containing a hand-drawn SVG outline of Ghana with
  # clickable region pins on the left, and the same regions as a
  # scrollable list with per-region store counts on the right.
  #
  # Both the SVG pins and the list buttons emit `phx-click="select_region"`
  # with `phx-value-region={slug}`. Backdrop and close button emit
  # `phx-click="close_map"`. Wiring lives in the parent LiveView.

  attr :stores, :list,
    required: true,
    doc: "Stores to plot. Each must have a :region string field."

  attr :active_region, :string, default: ""
  attr :open, :boolean, default: false

  def map_view(assigns) do
    assigns = assign(assigns, :region_rows, regions_with_counts(assigns.stores))

    ~H"""
    <div
      :if={@open}
      class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/70 backdrop-blur-sm"
      phx-click="close_map"
      role="dialog"
      aria-modal="true"
      aria-label="Browse stores by region"
    >
      <div
        class="bg-white rounded-3xl shadow-2xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto"
        phx-click-away="close_map"
      >
        <header class="flex items-center justify-between gap-4 px-6 pt-6 pb-4 border-b border-slate-200">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.2em] text-emerald-700">
              Browse by region
            </p>
            <h2 class="text-2xl font-bold text-slate-900 mt-0.5">Stores across Ghana</h2>
          </div>
          <button
            type="button"
            phx-click="close_map"
            class="w-10 h-10 rounded-full hover:bg-slate-100 flex items-center justify-center"
            aria-label="Close map"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="w-5 h-5 text-slate-700"
            >
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </header>

        <div class="grid md:grid-cols-2 gap-6 p-6">
          <div class="aspect-[4/5] rounded-2xl bg-slate-50 border border-slate-200 p-4 flex items-center justify-center">
            <svg
              viewBox="0 0 400 500"
              xmlns="http://www.w3.org/2000/svg"
              class="w-full h-full"
              role="img"
              aria-label="Outline map of Ghana with region pins"
            >
              <%!--
                Hand-drawn approximation of Ghana's outline.
                Tall north-south shape, narrower at the southern coast,
                wider in the north, with a slight bulge eastward where
                Volta meets Togo. Coast is a gentle curve along the
                bottom edge.
              --%>
              <path
                d="M 95 60
                   L 200 50
                   L 305 55
                   L 320 110
                   L 335 170
                   L 330 230
                   L 345 280
                   L 340 340
                   L 320 380
                   L 310 420
                   L 300 455
                   Q 230 478 165 470
                   Q 120 462 95 445
                   L 75 400
                   L 70 340
                   L 60 270
                   L 65 200
                   L 80 130
                   Z"
                fill="#fef3c7"
                stroke="#7A1F1F"
                stroke-width="2.5"
                stroke-linejoin="round"
              />

              <%!-- Region pins. Active region gets emerald; others amber. --%>
              <g
                :for={{slug, label, _count} <- @region_rows}
                phx-click="select_region"
                phx-value-region={slug}
                class="cursor-pointer"
                data-region={slug}
              >
                <circle
                  cx={pin_x(slug)}
                  cy={pin_y(slug)}
                  r="9"
                  fill={if slug == @active_region, do: "#059669", else: "#d4a843"}
                  stroke={if slug == @active_region, do: "#065f46", else: "#7A1F1F"}
                  stroke-width={if slug == @active_region, do: "3", else: "1.5"}
                />
                <text
                  x={pin_x(slug)}
                  y={pin_y(slug) + 24}
                  text-anchor="middle"
                  font-size="11"
                  font-weight="600"
                  fill="#1f2937"
                  style="paint-order: stroke; stroke: #ffffff; stroke-width: 3px;"
                >
                  {label}
                </text>
              </g>
            </svg>
          </div>

          <div class="space-y-2">
            <button
              :for={{slug, label, count} <- @region_rows}
              type="button"
              phx-click="select_region"
              phx-value-region={slug}
              class={[
                "w-full flex items-center justify-between px-4 py-3 rounded-xl border text-left transition-colors",
                if(slug == @active_region,
                  do: "border-emerald-600 bg-emerald-50 ring-2 ring-emerald-600",
                  else: "border-slate-200 bg-white hover:border-amber-400 hover:bg-amber-50"
                )
              ]}
            >
              <span class="font-semibold text-slate-900">{label}</span>
              <span class="text-xs text-slate-500">
                {count} {if count == 1, do: "store", else: "stores"}
              </span>
            </button>
          </div>
        </div>

        <footer class="px-6 py-4 border-t border-slate-200 text-xs text-slate-500 text-center">
          Pick a region to filter the directory.
        </footer>
      </div>
    </div>
    """
  end

  @doc """
  Returns `[{slug, label, count}]` for the canonical Ghanaian region list,
  where `count` is the number of `stores` whose `:region` equals `slug`.

  Stores with a nil/missing/unrecognized `:region` field do not contribute
  to any count (except the literal `"other"`, which buckets to Other).

  Order matches `regions/0` (minus the "All regions" sentinel).
  """
  def regions_with_counts(stores) when is_list(stores) do
    counts =
      Enum.reduce(stores, %{}, fn store, acc ->
        case Map.get(store, :region) do
          slug when is_binary(slug) -> Map.update(acc, slug, 1, &(&1 + 1))
          _ -> acc
        end
      end)

    @regions
    |> Enum.reject(fn {slug, _} -> slug == "" end)
    |> Enum.map(fn {slug, label} -> {slug, label, Map.get(counts, slug, 0)} end)
  end

  # Pin coordinate accessors. Falls back to map centroid so a
  # mistyped slug renders something visible rather than crashing.
  for {slug, {x, y}} <- @region_pins do
    defp pin_x(unquote(slug)), do: unquote(x)
    defp pin_y(unquote(slug)), do: unquote(y)
  end

  defp pin_x(_), do: 200
  defp pin_y(_), do: 250
end
