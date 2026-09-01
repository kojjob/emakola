defmodule Emakola.Themes.Fie.Shared do
  @moduledoc """
  Fie theme chrome and helpers — the quiet gallery wall around the
  merchant's photography.

  Fie is the home & décor catalogue: a modernist near-white ground held
  together by a blush frame (`#F7ECE7` panels inside `#EBDAD3` hairlines)
  so the whiteness never turns clinical. The chrome supplies no colour of
  its own beyond that frame — wood, clay and cloth in the merchant's
  photos do the warming. Geometry is sharp: hairline borders, square
  corners, Space Grotesk for headings and catalogue numerals.

  Owns the banner nav (cart reachable on desktop — the Market incident),
  the mobile tab bar, the blush footer, the CSS variable injection, and
  the pure helpers (images, stock, WhatsApp) the page renderers share.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  # ── Top navigation ──

  @doc """
  Fie's banner header — store identity linking home, desktop collection
  links, search as a plain link to the products page (no client event to
  crash on), and the cart link carrying the live count. Sticky so the
  cart stays one tap away on a long catalogue.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def fie_nav(assigns) do
    ~H"""
    <header
      role="banner"
      class="sticky top-0 z-50 border-b border-[#EBDAD3] bg-[#FDFCFB]/95 backdrop-blur"
    >
      <div class="mx-auto max-w-[1200px] px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between gap-3 sm:h-16">
          <a
            href={store_path(@store.slug, "/")}
            class="flex min-w-0 items-center gap-2.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2"
          >
            <span
              class="flex h-8 w-8 flex-shrink-0 items-center justify-center border border-[#EBDAD3] bg-[#F7ECE7] text-xs font-semibold text-stone-700 [font-family:'Space_Grotesk','Inter',sans-serif]"
              aria-hidden="true"
            >
              {String.first(@store.name)}
            </span>
            <span class="truncate text-base font-semibold tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif] sm:text-lg">
              {@store.name}
            </span>
          </a>

          <nav
            :if={@categories != []}
            class="hidden min-w-0 flex-1 items-center justify-center gap-6 md:flex"
            aria-label="Collections"
          >
            <a
              :for={category <- Enum.take(@categories, 5)}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="whitespace-nowrap text-sm font-medium text-stone-600 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              {category.name}
            </a>
          </nav>

          <div class="flex flex-shrink-0 items-center gap-0.5">
            <a
              href={store_path(@store.slug, "/products")}
              aria-label="Search the catalogue"
              class="flex h-11 w-11 items-center justify-center text-stone-600 hover:bg-[#F7ECE7] hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
            >
              <svg
                class="h-[22px] w-[22px]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.6"
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
              class="relative flex h-11 w-11 items-center justify-center text-stone-600 hover:bg-[#F7ECE7] hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
            >
              <svg
                class="h-[22px] w-[22px]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.6"
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
                class="absolute right-0.5 top-0.5 flex h-[18px] min-w-[18px] items-center justify-center bg-stone-900 px-1 text-[10px] font-semibold leading-none text-white tabular-nums"
              >
                {@cart_count}
              </span>
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Mobile bottom navigation ──

  @doc """
  Fie-owned mobile tab bar — Home, Search, Saved, Cart on the white
  ground with a blush hairline. `active` marks the current tab.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active, :atom, values: [:home, :search, :none], default: :home

  def fie_bottom_nav(assigns) do
    ~H"""
    <nav
      class="safe-area-inset-bottom fixed inset-x-0 bottom-0 z-40 border-t border-[#EBDAD3] bg-[#FDFCFB] sm:hidden"
      aria-label="Store"
    >
      <div class="flex h-14 items-center justify-around">
        <a
          href={store_path(@store.slug, "/")}
          aria-current={@active == :home && "page"}
          class={[
            "flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900",
            if(@active == :home, do: "text-stone-900", else: "text-stone-400 hover:text-stone-900")
          ]}
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
          <span class="text-[0.625rem] font-medium">Home</span>
        </a>
        <a
          href={store_path(@store.slug, "/products")}
          aria-current={@active == :search && "page"}
          class={[
            "flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900",
            if(@active == :search,
              do: "text-stone-900",
              else: "text-stone-400 hover:text-stone-900"
            )
          ]}
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
          class="flex flex-col items-center gap-0.5 px-3 py-1 text-stone-400 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
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
          class="relative flex flex-col items-center gap-0.5 px-3 py-1 text-stone-400 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
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
              class="absolute -right-1.5 -top-1 flex h-4 min-w-4 items-center justify-center bg-stone-900 px-0.5 text-[0.5rem] font-semibold leading-none text-white tabular-nums"
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

  # ── Footer ──

  @doc """
  Fie's own footer — the blush ground closing the catalogue. Brand block,
  shop / company / contact columns, socials only when configured, payment
  rails as quiet outline chips, secure-checkout mark, copyright. Email
  capture is NOT here — the `fie/newsletter` section owns it, so the page
  never carries two subscribe forms.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :theme, :map, default: %{}

  def footer(assigns) do
    theme = assigns[:theme] || %{}
    footer_config = get_in(theme, [:footer]) || %{}
    slug = assigns.store.slug

    company_links =
      Map.get(footer_config, :company_links, [
        %{label: "Our Story", url: store_path(slug, "/about")},
        %{label: "Contact", url: store_path(slug, "/contact")},
        %{label: "FAQ", url: store_path(slug, "/faq")},
        %{label: "Shipping & Returns", url: store_path(slug, "/policies#shipping")},
        %{label: "Privacy Policy", url: store_path(slug, "/policies#privacy")},
        %{label: "Terms of Service", url: store_path(slug, "/policies#terms")}
      ])

    social_links = Map.get(footer_config, :social_links) || %{}

    assigns =
      assigns
      |> assign(:company_links, company_links)
      |> assign(:social_links, social_links)

    ~H"""
    <%!-- Explicit role: the layout nests theme content inside <main>,
    which strips <footer>'s implicit contentinfo landmark. --%>
    <footer role="contentinfo" class="border-t border-[#EBDAD3] bg-[#F7ECE7] text-stone-900">
      <%!-- Mobile bottom padding clears the fixed fie_bottom_nav tab bar. --%>
      <div class="mx-auto max-w-[1200px] px-4 pb-28 pt-14 sm:px-6 sm:py-16 lg:px-8">
        <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1fr] lg:gap-8">
          <div>
            <a
              href={store_path(@store.slug, "/")}
              class="inline-flex min-h-[44px] items-center text-xl font-semibold tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif] hover:opacity-70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-opacity"
            >
              {@store.name}
            </a>
            <p
              :if={@store.description}
              class="mb-6 mt-3 max-w-xs text-sm leading-relaxed text-stone-600"
            >
              {@store.description}
            </p>
            <div :if={social_urls(@social_links) != []} class="mt-4 flex items-center gap-2">
              <.social_icon
                :for={{label, url, icon} <- social_urls(@social_links)}
                url={url}
                label={label}
                icon={icon}
              />
            </div>
          </div>

          <div>
            <h4 class="mb-5 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
              Shop
            </h4>
            <ul class="space-y-2">
              <li>
                <.footer_link href={store_path(@store.slug, "/products")}>
                  All Products
                </.footer_link>
              </li>
              <li :for={category <- Enum.take(@categories, 5)}>
                <.footer_link href={store_path(@store.slug, "/category/#{category.slug}")}>
                  {category.name}
                </.footer_link>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="mb-5 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
              Company
            </h4>
            <ul class="space-y-2">
              <li :for={link <- @company_links}>
                <.footer_link :if={Map.get(link, :url)} href={Map.get(link, :url)}>
                  {Map.get(link, :label)}
                </.footer_link>
                <span
                  :if={!Map.get(link, :url)}
                  class="inline-flex min-h-[44px] items-center text-sm text-stone-500"
                >
                  {Map.get(link, :label)}
                </span>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="mb-5 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
              Get in Touch
            </h4>
            <ul class="space-y-2">
              <li :if={wa_me(@store)}>
                <.footer_link href={wa_me(@store)}>
                  WhatsApp
                </.footer_link>
              </li>
              <li :if={Map.get(@store, :contact_email)}>
                <.footer_link href={"mailto:#{@store.contact_email}"}>
                  {@store.contact_email}
                </.footer_link>
              </li>
              <li :if={Map.get(@store, :contact_phone)}>
                <.footer_link href={"tel:#{@store.contact_phone}"}>
                  {@store.contact_phone}
                </.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/about")}>
                  About Us
                </.footer_link>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 border-t border-[#E0CCC4] pt-8">
          <div class="flex flex-col items-center justify-between gap-6 sm:flex-row">
            <div class="flex flex-wrap items-center justify-center gap-2">
              <span class="mr-2 text-[10px] uppercase tracking-[0.2em] text-stone-500">
                We Accept
              </span>
              <span
                :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}
                class="inline-flex items-center border border-[#E0CCC4] bg-white/60 px-2.5 py-1 text-[10px] font-semibold tracking-wide text-stone-700"
              >
                {rail}
              </span>
            </div>
            <div class="flex items-center gap-1.5 text-stone-500">
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                aria-hidden="true"
              >
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0110 0v4" />
              </svg>
              <span class="text-[10px] uppercase tracking-[0.2em]">Secure checkout</span>
            </div>
          </div>
        </div>

        <div class="mt-8 flex flex-col items-center justify-between gap-4 border-t border-[#E0CCC4] pt-8 sm:flex-row">
          <p class="text-xs text-stone-500">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-[10px] text-stone-500">
            Powered by <span class="font-semibold text-stone-700">Makola</span>
          </p>
        </div>
      </div>
    </footer>
    """
  end

  attr :href, :string, required: true
  slot :inner_block, required: true

  defp footer_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="inline-flex min-h-[44px] items-center gap-2 text-sm text-stone-600 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr :url, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true

  defp social_icon(assigns) do
    ~H"""
    <a
      href={@url}
      class="flex h-11 w-11 items-center justify-center text-stone-500 hover:bg-white/60 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
      aria-label={@label}
      target="_blank"
      rel="noopener noreferrer"
    >
      <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d={@icon} />
      </svg>
    </a>
    """
  end

  @social_icons [
    {:instagram, "Instagram",
     "M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"},
    {:twitter, "Twitter",
     "M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"},
    {:facebook, "Facebook",
     "M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"},
    {:tiktok, "TikTok",
     "M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1v-3.5a6.37 6.37 0 00-.79-.05A6.34 6.34 0 003.15 15.2a6.34 6.34 0 0010.86 4.46V12.8a8.28 8.28 0 005.58 2.17V11.5a4.85 4.85 0 01-3.77-1.85V6.69h3.77z"}
  ]

  # Only socials the merchant actually configured — no dead placeholder
  # icons. Theme defaults store "" for unset socials, so blank counts as
  # absent alongside nil.
  defp social_urls(social_links) do
    for {key, label, icon} <- @social_icons,
        url = Map.get(social_links, key),
        is_binary(url) and url != "",
        do: {label, url, icon}
  end

  # ── CSS variable injection ──

  @doc """
  Injects theme CSS custom properties into the page as a <style> block.
  Place this as the first element inside the outermost div of each page.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#211C1A") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#8A5B4C") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FDFCFB") %>;
      }
    </style>
    """
  end

  # ── Pure helpers ──

  @doc """
  The compare-at ("was") price to show next to a piece's price, in minor
  units, or nil.

  Shown only when the product has a single price point (min == max) and
  its cheapest loaded variant carries a compare_at_price above its price —
  striking through a "was" price next to a price *range* would be
  ambiguous. Products whose variants aren't loaded show no sale treatment:
  fail quiet, never crash.
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
  `Emakola.Catalog.Variant.in_stock?/1` is the single purchasability rule.
  Products whose variants aren't loaded (or that have none) fail open to
  purchasable: the `add_to_cart` handler re-checks stock server-side.
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
  Bare wa.me link to the store's WhatsApp number (digits only), or nil
  when the store has no usable number.
  """
  def wa_me(store) do
    case whatsapp_digits(store) do
      nil -> nil
      digits -> "https://wa.me/#{digits}"
    end
  end

  @doc """
  wa.me link to the store's WhatsApp number prefilled with the product
  title, or nil when the store has no number.
  """
  def whatsapp_link(store, product_title) do
    case whatsapp_digits(store) do
      nil ->
        nil

      digits ->
        message = "Hi, I'm interested in #{product_title} from #{Map.get(store, :name)}"
        "https://wa.me/#{digits}?text=#{URI.encode_www_form(message)}"
    end
  end

  defp whatsapp_digits(store) do
    case Map.get(store, :whatsapp_number) do
      number when is_binary(number) ->
        case String.replace(number, ~r/\D/, "") do
          "" -> nil
          digits -> digits
        end

      _ ->
        nil
    end
  end
end
