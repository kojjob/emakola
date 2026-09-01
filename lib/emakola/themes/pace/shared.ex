defmodule Emakola.Themes.Pace.Shared do
  @moduledoc """
  Pace theme chrome and helpers (spec:
  docs/superpowers/specs/2026-07-12-seven-themes-contract.md).

  The theme's three fixed moves live here:

    * The ice ground — every page frames its content in the merchant's
      background colour (`--theme-bg`, default ice blue) with the content
      on a white rounded canvas, like a track inside its verge.
    * The floating pill nav — sticky, rounded-full, cart always one tap
      away on every page and every breakpoint.
    * The night slab footer — the dark-gradient card family at page scale.

  `theme_styles/1` also carries the theme's only two CSS extensions:
  the `.pace-display` face (Chakra Petch, deferring to the merchant's
  heading token) and the `pace-marquee` keyframes, applied strictly
  inside a `prefers-reduced-motion: no-preference` guard.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  # ── CSS variables + theme-owned styles ──

  @doc """
  Injects theme CSS custom properties and Pace's display-face/marquee
  rules. Place as the first element inside each page's outermost div.

  The marquee animation is defined only for users who have NOT asked for
  reduced motion — with the preference set, the ghost wordmark renders as
  a static composed crop, which is a finished look, not a fallback.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#1D4ED8") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#0F172A") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#E6EFF6") %>;
      }
      .pace-display { font-family: var(--dt-heading-font, 'Chakra Petch', system-ui, sans-serif); }
      @keyframes pace-marquee {
        from { transform: translateX(0); }
        to { transform: translateX(-50%); }
      }
      @media (prefers-reduced-motion: no-preference) {
        .pace-marquee { animation: pace-marquee 38s linear infinite; }
      }
    </style>
    """
  end

  # ── Top navigation ──

  @doc """
  Pace's floating pill nav — a rounded-full bar hovering over the ice
  ground. Store identity in the display face, desktop category links,
  search as a plain link to the products page (no client event to crash
  on), and the cart link carrying the live count. Sticky so the cart
  stays one tap away on a long scroll; present on all three pages so
  desktop shoppers are never stranded.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def pace_nav(assigns) do
    ~H"""
    <header role="banner" class="sticky top-2 z-50 px-2 sm:px-4 lg:px-6">
      <div class="mx-auto flex h-14 max-w-[1280px] items-center justify-between gap-3 rounded-full border border-white/70 bg-white/90 px-2.5 shadow-[0_8px_30px_rgba(13,38,64,0.10)] backdrop-blur sm:h-16 sm:px-4">
        <a
          href={store_path(@store.slug, "/")}
          class="flex min-w-0 items-center gap-2.5 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2"
        >
          <span
            class="pace-display flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full bg-slate-950 text-sm font-bold italic text-white"
            aria-hidden="true"
          >
            {String.first(@store.name)}
          </span>
          <span class="pace-display truncate text-base font-bold uppercase italic tracking-tight text-slate-950 sm:text-lg">
            {@store.name}
          </span>
        </a>

        <nav
          :if={@categories != []}
          class="hidden min-w-0 flex-1 items-center justify-center gap-6 md:flex"
          aria-label="Categories"
        >
          <a
            :for={category <- Enum.take(@categories, 5)}
            href={store_path(@store.slug, "/category/#{category.slug}")}
            class="whitespace-nowrap rounded text-xs font-semibold uppercase tracking-[0.14em] text-slate-500 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            {category.name}
          </a>
        </nav>

        <div class="flex flex-shrink-0 items-center gap-0.5">
          <a
            href={store_path(@store.slug, "/products")}
            aria-label="Search products"
            class="flex h-11 w-11 items-center justify-center rounded-full text-slate-600 hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 motion-safe:transition-colors"
          >
            <svg
              class="h-[22px] w-[22px]"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.8"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
              />
            </svg>
          </a>
          <a
            href={store_path(@store.slug, "/cart")}
            aria-label={"Shopping cart, #{Emakola.Plural.count(@cart_count, "item")}"}
            class="relative flex h-11 w-11 items-center justify-center rounded-full text-slate-600 hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 motion-safe:transition-colors"
          >
            <svg
              class="h-[22px] w-[22px]"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.8"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
              />
            </svg>
            <span
              :if={@cart_count > 0}
              class="absolute right-0.5 top-0.5 flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-store-accent px-1 text-[10px] font-bold leading-none text-white"
            >
              {@cart_count}
            </span>
          </a>
        </div>
      </div>
    </header>
    """
  end

  # ── Mobile bottom navigation ──

  @doc """
  Pace's mobile tab bar — a floating night pill with Home, Search, Saved,
  Cart. Mobile-only; the pill nav above keeps the cart reachable on
  desktop.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active_tab, :atom, default: :home, values: [:home, :search, :saved, :cart]

  def pace_bottom_nav(assigns) do
    ~H"""
    <nav
      class="safe-area-inset-bottom fixed inset-x-2 bottom-2 z-40 rounded-full bg-slate-950 shadow-[0_8px_30px_rgba(2,6,23,0.35)] sm:hidden"
      aria-label="Store"
    >
      <div class="flex h-14 items-center justify-around">
        <a
          href={store_path(@store.slug, "/")}
          aria-current={@active_tab == :home && "page"}
          class={tab_classes(@active_tab == :home)}
        >
          <svg
            class="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
            />
          </svg>
          <span class="text-[0.625rem] font-semibold">Home</span>
        </a>
        <a
          href={store_path(@store.slug, "/products")}
          aria-current={@active_tab == :search && "page"}
          class={tab_classes(@active_tab == :search)}
        >
          <svg
            class="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
            />
          </svg>
          <span class="text-[0.625rem] font-medium">Search</span>
        </a>
        <a
          href={store_path(@store.slug, "/wishlist")}
          aria-current={@active_tab == :saved && "page"}
          class={tab_classes(@active_tab == :saved)}
        >
          <svg
            class="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
            />
          </svg>
          <span class="text-[0.625rem] font-medium">Saved</span>
        </a>
        <a
          href={store_path(@store.slug, "/cart")}
          aria-current={@active_tab == :cart && "page"}
          class={["relative", tab_classes(@active_tab == :cart)]}
          aria-label={"Cart, #{Emakola.Plural.count(@cart_count, "item")}"}
        >
          <span class="relative">
            <svg
              class="h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.5"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
              />
            </svg>
            <span
              :if={@cart_count > 0}
              class="absolute -right-1.5 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-store-accent px-0.5 text-[0.5rem] font-bold leading-none text-white"
            >
              {@cart_count}
            </span>
          </span>
          <span class="text-[0.625rem] font-medium">Cart</span>
        </a>
      </div>
    </nav>
    """
  end

  defp tab_classes(active?) do
    [
      "flex flex-col items-center gap-0.5 rounded-full px-3 py-1",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white",
      if(active?, do: "text-white", else: "text-slate-400 hover:text-white")
    ]
  end

  # ── Footer ──

  defdelegate footer(assigns), to: Emakola.Themes.Pace.Footer

  # ── Data helpers (shared across the three pages) ──

  @doc """
  The compare-at ("was") price to show next to a product's price, in
  minor units, or nil.

  Shown only when the product has a single price point (min == max) and
  its cheapest loaded variant carries a compare_at_price above its price
  — a "was" price next to a price *range* would be ambiguous. Products
  whose variants aren't loaded show no sale treatment: fail quiet, never
  crash.
  """
  def compare_at_price(product) do
    with %{min_price: min, max_price: max} when is_integer(min) and min == max <- product,
         [_ | _] = variants <- loaded_variants(product),
         %{price: price, compare_at_price: compare} <- Enum.min_by(variants, & &1.price),
         true <- is_integer(compare) and is_integer(price) and compare > price do
      compare
    else
      _ -> nil
    end
  end

  @doc """
  True when every loaded variant is out of stock —
  `Emakola.Catalog.Variant.in_stock?/1` is the single purchasability
  rule. Products whose variants aren't loaded (or that have none) fail
  open to purchasable: the `add_to_cart` handler re-checks stock
  server-side.
  """
  def sold_out?(product) do
    case loaded_variants(product) do
      [_ | _] = variants -> not Enum.any?(variants, &Emakola.Catalog.Variant.in_stock?/1)
      _ -> false
    end
  end

  defp loaded_variants(%{variants: variants}) when is_list(variants), do: variants
  defp loaded_variants(_product), do: []

  @doc """
  Extract the first image URL from a product's images association.
  Returns thumbnail_url if available, falls back to url, then nil.
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc """
  Get the image at a specific index from a product's images.
  Falls back to medium_url, then url, then first_image.
  """
  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

  @doc """
  wa.me link to the store's WhatsApp number prefilled with the product
  title, or nil when the store has no number.
  """
  def whatsapp_link(store, product_title) do
    case Map.get(store, :whatsapp_number) do
      number when is_binary(number) ->
        digits = String.replace(number, ~r/\D/, "")

        if digits == "" do
          nil
        else
          message = "Hi, I'm interested in #{product_title} from #{Map.get(store, :name)}"
          "https://wa.me/#{digits}?text=#{URI.encode_www_form(message)}"
        end

      _ ->
        nil
    end
  end
end
