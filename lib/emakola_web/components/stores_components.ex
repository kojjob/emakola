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
