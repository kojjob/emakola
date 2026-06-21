defmodule EmakolaWeb.StoresComponents do
  @moduledoc """
  Components used by the public `/stores` directory.

  - `store_card/1` — primary card; cover image, logo, name, tagline,
    theme/region pill, product count, rating, "Visit shop" CTA, ♡ button.
  - `filter_chips/1` — theme filter chips (All + one chip per registered theme).
  - `region_filter/1` — dropdown for Ghana regions.
  - `sort_dropdown/1` — Newest / A-Z / Most popular / Featured.
  - `featured_carousel/1` — horizontal-scroll snap row of featured stores.
  - `recently_viewed_strip/1` — 6-up horizontal strip from cookie.
  - `map_view/1` — Ghana SVG with regional pins (Phase 3).
  """

  use Phoenix.Component

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

  @doc "Curated Ghana regions (slug → label)."
  def regions, do: @regions

  @doc "Sort dropdown options."
  def sorts, do: @sorts

  # ── Store card (default variant) ──

  attr :store, :map, required: true
  attr :is_favorite, :boolean, default: false
  attr :variant, :atom, default: :default, values: [:default, :featured, :editorial, :compact]

  def store_card(assigns) do
    ~H"""
    <article class={[
      "group relative bg-white rounded-2xl overflow-hidden border border-slate-200 hover:border-slate-300 hover:shadow-lg transition-all flex flex-col",
      card_variant_class(@variant)
    ]}>
      <%!-- Cover --%>
      <a href={"/@#{@store.slug}"} class="block relative aspect-[16/9] overflow-hidden">
        <%= if @store.cover_image_url && @store.cover_image_url != "" do %>
          <.optimized_image
            src={@store.cover_image_url}
            alt={"#{@store.name} cover"}
            class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
          />
        <% else %>
          <div
            class="absolute inset-0 bg-[linear-gradient(135deg,var(--color-store-accent),var(--color-cta-dark))]"
            style={card_theme_vars(@store)}
          >
          </div>
          <div class="absolute inset-0 flex items-center justify-center">
            <span
              class="material-symbols-outlined text-white/40"
              style="font-size: 80px;"
            >
              storefront
            </span>
          </div>
        <% end %>

        <%!-- Featured / Verified pills --%>
        <div class="absolute top-3 right-3 flex items-center gap-1.5">
          <span
            :if={Map.get(@store, :featured)}
            class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-400/95 text-amber-950 text-[10px] font-bold uppercase tracking-wider backdrop-blur-sm"
          >
            <span class="material-symbols-outlined" style="font-size: 12px;">star</span> Featured
          </span>
          <span
            :if={Map.get(@store, :verified)}
            class="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-sky-500/95 text-white text-[10px] font-bold uppercase tracking-wider backdrop-blur-sm"
            title="Verified merchant"
          >
            <span class="material-symbols-outlined" style="font-size: 12px;">verified</span>
          </span>
        </div>

        <%!-- Logo overlay (bottom-left) --%>
        <div class="absolute -bottom-6 left-4 w-14 h-14 rounded-2xl border-4 border-white bg-white shadow-md overflow-hidden flex items-center justify-center">
          <%= if @store.logo_url && @store.logo_url != "" do %>
            <img
              src={@store.logo_url}
              alt={"#{@store.name} logo"}
              class="w-full h-full object-cover"
              loading="lazy"
            />
          <% else %>
            <span
              class="text-base font-bold text-store-accent"
              style={card_theme_vars(@store)}
            >
              {String.first(@store.name) |> String.upcase()}
            </span>
          <% end %>
        </div>
      </a>

      <%!-- Body --%>
      <div class="px-4 pt-9 pb-4 flex-1 flex flex-col">
        <a
          href={"/@#{@store.slug}"}
          class="text-base font-bold text-slate-900 hover:text-emerald-700 transition-colors line-clamp-1"
        >
          {@store.name}
        </a>

        <p
          :if={Map.get(@store, :tagline) && @store.tagline != ""}
          class="text-sm text-slate-700 mt-1 line-clamp-1"
        >
          {@store.tagline}
        </p>

        <p
          :if={(!Map.get(@store, :tagline) || @store.tagline == "") && @store.description}
          class="text-sm text-slate-500 mt-1 line-clamp-2"
        >
          {@store.description}
        </p>

        <%!-- Meta line --%>
        <div class="flex items-center gap-1.5 text-xs text-slate-500 mt-3 flex-wrap">
          <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-slate-100">
            {theme_label(@store)}
          </span>
          <span :if={location(@store) != ""} class="inline-flex items-center gap-1">
            <span class="material-symbols-outlined" style="font-size: 12px;">location_on</span>
            {location(@store)}
          </span>
        </div>

        <%!-- Stats --%>
        <div class="flex items-center gap-3 text-xs text-slate-600 mt-2">
          <span :if={product_count(@store) > 0} class="inline-flex items-center gap-1">
            <span class="material-symbols-outlined text-slate-400" style="font-size: 14px;">
              inventory_2
            </span>
            {product_count(@store)} {if product_count(@store) == 1, do: "product", else: "products"}
          </span>
        </div>

        <%!-- Actions --%>
        <div class="flex items-center gap-2 mt-4 pt-3 border-t border-slate-100">
          <a
            href={"/@#{@store.slug}"}
            class="flex-1 inline-flex items-center justify-center gap-1.5 px-4 py-2 rounded-lg bg-slate-900 text-white text-xs font-semibold hover:bg-slate-700 transition-colors"
          >
            Visit shop
            <span class="material-symbols-outlined" style="font-size: 14px;">arrow_forward</span>
          </a>
          <button
            phx-click="toggle_favorite"
            phx-value-slug={@store.slug}
            class={[
              "w-9 h-9 rounded-lg border flex items-center justify-center transition-colors",
              if(@is_favorite,
                do: "bg-rose-50 border-rose-200 text-rose-600 hover:bg-rose-100",
                else:
                  "bg-white border-slate-200 text-slate-400 hover:border-rose-200 hover:text-rose-500"
              )
            ]}
            aria-label={if @is_favorite, do: "Unsave store", else: "Save store"}
          >
            <span
              class="material-symbols-outlined"
              style={"font-size: 18px; font-variation-settings: 'FILL' #{if @is_favorite, do: 1, else: 0};"}
            >
              favorite
            </span>
          </button>
        </div>
      </div>
    </article>
    """
  end

  defp card_variant_class(:featured), do: "lg:col-span-2"
  defp card_variant_class(:editorial), do: "bg-slate-900 text-white border-slate-800"
  defp card_variant_class(:compact), do: ""
  defp card_variant_class(_), do: ""

  # ── Featured carousel (horizontal snap) ──
  #
  # Renders a horizontally scrolling row of taller hero cards. Pure CSS
  # scroll-snap; no JS hook needed. Each card uses the same color/logo
  # treatment as `store_card/1` but with a larger cover and editorial
  # vibe (tagline takes precedence over description).

  attr :stores, :list, required: true

  def featured_carousel(assigns) do
    ~H"""
    <section :if={@stores != []} class="relative bg-slate-50 border-y border-slate-200">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-4">
        <div class="flex items-end justify-between gap-3 mb-5">
          <div class="flex items-center gap-4">
            <span class="hidden sm:flex w-12 h-12 rounded-2xl items-center justify-center shrink-0 shadow-md bg-gradient-to-br from-amber-400 to-orange-500">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class="w-7 h-7 text-white"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="m12 2 3 6.5 7 1-5.1 4.9 1.2 7-6.1-3.3-6.1 3.3 1.2-7L2 9.5l7-1L12 2Z" />
              </svg>
            </span>
            <div>
              <p class="text-xs font-bold uppercase tracking-[0.2em] text-amber-700">
                Featured shops
              </p>
              <h2 class="text-2xl sm:text-3xl font-black text-slate-900 mt-0.5">
                Spotlight on Ghana's best
              </h2>
              <p class="text-sm text-slate-500 mt-0.5">Hand-picked by our team</p>
            </div>
          </div>
        </div>
      </div>

      <div class="relative">
        <div
          class="overflow-x-auto scroll-smooth snap-x snap-mandatory pb-6 -mx-4 sm:mx-0 px-4 sm:px-0 scrollbar-hide"
          style="scrollbar-width: none;"
        >
          <div class="max-w-[1280px] mx-auto sm:px-6 lg:px-8">
            <div class="flex gap-4 sm:gap-5 min-w-max sm:min-w-0">
              <a
                :for={store <- @stores}
                href={"/@#{store.slug}"}
                class="snap-start group relative w-[280px] sm:w-[320px] shrink-0 rounded-2xl overflow-hidden bg-white ring-1 ring-slate-200 hover:ring-2 hover:ring-amber-300 shadow-sm hover:shadow-xl transition-all hover:-translate-y-1"
              >
                <div class="relative aspect-[4/3] overflow-hidden">
                  <%= if store.cover_image_url && store.cover_image_url != "" do %>
                    <.optimized_image
                      src={store.cover_image_url}
                      alt={"#{store.name} cover"}
                      class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                    />
                  <% else %>
                    <div
                      class="absolute inset-0 bg-[linear-gradient(135deg,var(--color-store-accent),var(--color-cta-dark))]"
                      style={card_theme_vars(store)}
                    >
                    </div>
                    <div class="absolute inset-0 flex items-center justify-center">
                      <span class="material-symbols-outlined text-white/30" style="font-size: 96px;">
                        storefront
                      </span>
                    </div>
                  <% end %>

                  <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent">
                  </div>

                  <span class="absolute top-3 right-3 inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-400 text-amber-950 text-[10px] font-bold uppercase tracking-wider">
                    <span class="material-symbols-outlined" style="font-size: 12px;">star</span>
                    Featured
                  </span>

                  <%!-- Logo + name overlay --%>
                  <div class="absolute bottom-3 left-3 right-3 flex items-end gap-3">
                    <div class="w-12 h-12 rounded-xl border-2 border-white/90 bg-white shadow-md overflow-hidden flex items-center justify-center shrink-0">
                      <%= if store.logo_url && store.logo_url != "" do %>
                        <img
                          src={store.logo_url}
                          alt={"#{store.name} logo"}
                          class="w-full h-full object-cover"
                          loading="lazy"
                        />
                      <% else %>
                        <span
                          class="text-base font-bold text-store-accent"
                          style={card_theme_vars(store)}
                        >
                          {String.first(store.name) |> String.upcase()}
                        </span>
                      <% end %>
                    </div>
                    <div class="min-w-0 flex-1">
                      <p class="text-white text-base font-bold drop-shadow line-clamp-1">
                        {store.name}
                      </p>
                      <p
                        :if={Map.get(store, :tagline) && store.tagline != ""}
                        class="text-white/85 text-xs line-clamp-1"
                      >
                        {store.tagline}
                      </p>
                    </div>
                  </div>
                </div>

                <div class="px-4 py-3 flex items-center justify-between gap-2 text-xs text-slate-600">
                  <span :if={location(store) != ""} class="inline-flex items-center gap-1 font-medium">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 24 24"
                      class="w-3.5 h-3.5 text-slate-400"
                      fill="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M11.5 22.4a.75.75 0 0 0 1 0c4.5-3.5 8-7.2 8-12.1A8.5 8.5 0 0 0 12 1.75a8.5 8.5 0 0 0-8.5 8.55c0 4.9 3.5 8.6 8 12.1ZM12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    {location(store)}
                  </span>
                  <span class="inline-flex items-center gap-1 text-amber-700 font-bold ml-auto group-hover:gap-1.5 transition-all">
                    Visit shop
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
              href={"/@#{store.slug}"}
              class="group block w-[260px] sm:w-[290px] shrink-0 bg-white rounded-3xl overflow-hidden ring-1 ring-slate-200 hover:ring-2 hover:ring-emerald-300 shadow-sm hover:shadow-2xl hover:shadow-emerald-500/15 hover:-translate-y-1 transition-all duration-300"
            >
              <%!-- IMAGE HERO --%>
              <div class="relative h-48 w-full overflow-hidden bg-slate-100">
                <%= if store.cover_image_url && store.cover_image_url != "" do %>
                  <.optimized_image
                    src={store.cover_image_url}
                    alt={"#{store.name} cover"}
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
                        id={"diag-#{store.slug}"}
                        width="14"
                        height="14"
                        patternUnits="userSpaceOnUse"
                        patternTransform="rotate(45)"
                      >
                        <line x1="0" y="0" x2="0" y2="14" stroke="white" stroke-width="2" />
                      </pattern>
                    </defs>
                    <rect width="100%" height="100%" fill={"url(#diag-#{store.slug})"} />
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
                <span :if={location(store) == ""} class="text-slate-400 italic">
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
            href={"/@#{store.slug}"}
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
    chips = [{"all", "All", "view_module"}] ++ theme_chips()
    assigns = assign(assigns, :chips, chips)

    ~H"""
    <div class="flex flex-wrap gap-2">
      <button
        :for={{value, label, icon} <- @chips}
        type="button"
        phx-click="select_theme"
        phx-value-theme={value}
        class={[
          "inline-flex items-center gap-1.5 px-4 py-2 rounded-full text-xs font-semibold transition-colors min-h-[36px]",
          if(@active_theme == value,
            do: "bg-slate-900 text-white",
            else:
              "bg-white border border-slate-200 text-slate-700 hover:border-slate-400 hover:text-slate-900"
          )
        ]}
      >
        <span class="material-symbols-outlined" style="font-size: 16px;">{icon}</span>
        {label}
        <span
          :if={(c = Map.get(@counts, value)) && c > 0}
          class={[
            "inline-flex items-center px-1.5 rounded-full text-[10px] font-bold",
            if(@active_theme == value, do: "bg-white/20", else: "bg-slate-100")
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
      {"market", "Market", "storefront"},
      {"atelier", "Atelier", "diamond"},
      {"vibrant", "Vibrant", "palette"},
      {"starter", "Starter", "auto_awesome"},
      {"bold", "Bold", "newspaper"},
      {"fresh", "Fresh", "eco"},
      {"pharmacy", "Pharmacy", "medical_services"},
      {"beauty", "Beauty", "spa"},
      {"home_living", "Home Living", "chair"},
      {"electronics", "Electronics", "devices"},
      {"fashion", "Fashion", "checkroom"}
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
    case theme_id(store) do
      nil ->
        "Store"

      id ->
        Enum.find_value(theme_chips(), "Store", fn {chip_id, label, _icon} ->
          if chip_id == id, do: label
        end)
    end
  end

  defp theme_id(store) do
    case Map.get(store, :theme_config) do
      %{"theme" => id} when is_binary(id) -> id
      _ -> "market"
    end
  end

  defp theme_primary(store) do
    case theme_id(store) do
      nil -> "#1F2937"
      id -> resolve_color(id, :primary, "#1F2937")
    end
  end

  defp theme_accent(store) do
    case theme_id(store) do
      nil -> "#0EA5E9"
      id -> resolve_color(id, :accent, "#0EA5E9")
    end
  end

  # Scopes the store's theme colors onto a single card element so the
  # `--color-store-accent` / `--color-cta-dark` utilities resolve per-card.
  # Setting the color tokens directly is the simplest override: inline
  # style declarations are unlayered, so they beat the `@layer theme`
  # :root token declarations for this element and its descendants.
  defp card_theme_vars(store) do
    "--color-store-accent: #{CssColor.safe_css_color(theme_primary(store), "#B45309")}; " <>
      "--color-cta-dark: #{CssColor.safe_css_color(theme_accent(store), "#1C1917")}"
  end

  defp resolve_color(theme_id, key, fallback) do
    module = ThemeResolver.theme_module(theme_id)

    if module && function_exported?(module, :defaults, 0) do
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
