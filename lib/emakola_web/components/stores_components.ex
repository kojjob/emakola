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
      <a href={"/s/#{@store.slug}"} class="block relative aspect-[16/9] overflow-hidden">
        <%= if @store.cover_image_url && @store.cover_image_url != "" do %>
          <.optimized_image
            src={@store.cover_image_url}
            alt={"#{@store.name} cover"}
            class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
          />
        <% else %>
          <div
            class="absolute inset-0"
            style={"background: linear-gradient(135deg, #{theme_primary(@store)} 0%, #{theme_accent(@store)} 100%);"}
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
              class="text-base font-bold"
              style={"color: #{theme_primary(@store)};"}
            >
              {String.first(@store.name) |> String.upcase()}
            </span>
          <% end %>
        </div>
      </a>

      <%!-- Body --%>
      <div class="px-4 pt-9 pb-4 flex-1 flex flex-col">
        <a
          href={"/s/#{@store.slug}"}
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
            href={"/s/#{@store.slug}"}
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
    <section :if={@stores != []} class="relative -mt-2">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-8 pb-2">
        <div class="flex items-end justify-between gap-3 mb-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-amber-400">
              Featured shops
            </p>
            <h2 class="text-2xl sm:text-3xl font-bold text-white mt-1">
              Spotlight on Ghana's best
            </h2>
          </div>
          <p class="text-xs text-white/50 hidden sm:block">
            Hand-picked by our team
          </p>
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
                href={"/s/#{store.slug}"}
                class="snap-start group relative w-[280px] sm:w-[320px] shrink-0 rounded-2xl overflow-hidden border border-white/10 bg-white/[0.03] hover:bg-white/[0.06] transition-all"
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
                      class="absolute inset-0"
                      style={"background: linear-gradient(135deg, #{theme_primary(store)} 0%, #{theme_accent(store)} 100%);"}
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
                          class="text-base font-bold"
                          style={"color: #{theme_primary(store)};"}
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

                <div class="px-4 py-3 flex items-center justify-between gap-2 text-xs text-white/70">
                  <span class="inline-flex items-center gap-1">
                    <span class="material-symbols-outlined" style="font-size: 12px;">
                      location_on
                    </span>
                    {location(store)}
                  </span>
                  <span class="inline-flex items-center gap-1 text-amber-300 font-semibold">
                    Visit shop
                    <span class="material-symbols-outlined" style="font-size: 14px;">
                      arrow_forward
                    </span>
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

  # ── New-on-Emakola strip (compact horizontal) ──

  attr :stores, :list, required: true
  attr :title, :string, default: "New on Emakola"
  attr :subtitle, :string, default: "Just joined the marketplace"

  def recent_strip(assigns) do
    ~H"""
    <section :if={@stores != []}>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="flex items-end justify-between gap-4 mb-7 flex-wrap">
          <div class="flex items-center gap-4">
            <span class="hidden sm:flex w-12 h-12 rounded-2xl bg-emerald-100 items-center justify-center shrink-0">
              <span class="material-symbols-outlined text-emerald-700" style="font-size: 24px;">
                auto_awesome
              </span>
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
            class="hidden sm:inline-flex items-center gap-1.5 text-sm font-semibold text-slate-700 hover:text-emerald-700 transition-colors"
          >
            View all stores
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>

        <%!--
          Flex-wrap layout instead of rigid grid: cards keep a consistent
          width but flow naturally so 1-2 stores look intentional rather
          than leaving 4 empty grid cells. Mobile gets horizontal scroll.
        --%>
        <div class="overflow-x-auto -mx-4 sm:mx-0 px-4 sm:px-0 scrollbar-hide pb-2">
          <div class="flex flex-nowrap sm:flex-wrap gap-5 sm:gap-6 min-w-max sm:min-w-0">
            <a
              :for={store <- @stores}
              href={"/s/#{store.slug}"}
              class="group block w-[200px] sm:w-[220px] shrink-0"
            >
              <div class="relative aspect-square overflow-hidden rounded-2xl bg-white border border-slate-200 group-hover:border-emerald-300 group-hover:shadow-lg transition-all">
                <%= if store.cover_image_url && store.cover_image_url != "" do %>
                  <.optimized_image
                    src={store.cover_image_url}
                    alt={"#{store.name}"}
                    class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                  />
                <% else %>
                  <div
                    class="absolute inset-0"
                    style={"background: linear-gradient(135deg, #{theme_primary(store)} 0%, #{theme_accent(store)} 100%);"}
                  >
                  </div>
                  <div class="absolute inset-0 flex items-center justify-center">
                    <span class="material-symbols-outlined text-white/30" style="font-size: 64px;">
                      storefront
                    </span>
                  </div>
                <% end %>

                <%!-- Subtle gradient at bottom for legibility --%>
                <div class="absolute inset-x-0 bottom-0 h-1/2 bg-gradient-to-t from-black/50 to-transparent">
                </div>

                <span class="absolute top-2.5 left-2.5 inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-emerald-500 text-white text-[10px] font-bold uppercase tracking-wider shadow">
                  <span class="material-symbols-outlined" style="font-size: 12px;">
                    fiber_new
                  </span>
                  New
                </span>

                <%= if store.logo_url && store.logo_url != "" do %>
                  <img
                    src={store.logo_url}
                    alt={"#{store.name} logo"}
                    class="absolute bottom-3 left-3 w-11 h-11 rounded-xl border-2 border-white object-cover bg-white shadow-md"
                    loading="lazy"
                  />
                <% else %>
                  <div class="absolute bottom-3 left-3 w-11 h-11 rounded-xl border-2 border-white bg-white shadow-md flex items-center justify-center">
                    <span class="text-base font-bold" style={"color: #{theme_primary(store)};"}>
                      {String.first(store.name) |> String.upcase()}
                    </span>
                  </div>
                <% end %>
              </div>

              <div class="mt-3">
                <p class="text-base font-bold text-slate-900 line-clamp-1 group-hover:text-emerald-700 transition-colors">
                  {store.name}
                </p>
                <div class="flex items-center gap-2 mt-1 text-xs text-slate-500">
                  <span class="inline-flex items-center gap-0.5 px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 font-medium">
                    {theme_label(store)}
                  </span>
                  <span :if={location(store) != ""} class="inline-flex items-center gap-0.5 truncate">
                    <span class="material-symbols-outlined" style="font-size: 12px;">
                      location_on
                    </span>
                    <span class="truncate">{location(store)}</span>
                  </span>
                </div>
              </div>
            </a>

            <%!--
              Final CTA card. Always rendered so the strip never looks
              empty — fills the trailing whitespace when there are fewer
              stores than columns and gives users a path to the full grid.
            --%>
            <a
              href="#main-grid"
              class="group block w-[200px] sm:w-[220px] shrink-0"
            >
              <div class="relative aspect-square overflow-hidden rounded-2xl border-2 border-dashed border-slate-300 hover:border-emerald-400 bg-slate-50 hover:bg-emerald-50/40 flex flex-col items-center justify-center text-center px-5 transition-all">
                <span class="w-12 h-12 rounded-2xl bg-white border border-slate-200 group-hover:border-emerald-300 flex items-center justify-center shadow-sm transition-colors">
                  <span class="material-symbols-outlined text-emerald-600" style="font-size: 24px;">
                    explore
                  </span>
                </span>
                <p class="text-base font-bold text-slate-900 mt-3 group-hover:text-emerald-700 transition-colors">
                  Explore all stores
                </p>
                <p class="text-xs text-slate-500 mt-1">
                  Browse the full marketplace
                </p>
                <span
                  class="material-symbols-outlined text-slate-400 group-hover:text-emerald-600 group-hover:translate-x-0.5 transition-all mt-2"
                  style="font-size: 18px;"
                >
                  arrow_forward
                </span>
              </div>
              <div class="mt-3 invisible">
                <p class="text-base font-bold">.</p>
                <p class="text-xs">.</p>
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
            href={"/s/#{store.slug}"}
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
                  class="absolute inset-0"
                  style={"background: linear-gradient(135deg, #{theme_primary(store)} 0%, #{theme_accent(store)} 100%);"}
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
end
