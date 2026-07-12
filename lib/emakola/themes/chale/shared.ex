defmodule Emakola.Themes.Chale.Shared do
  @moduledoc """
  Chale theme chrome and card components — poster-on-concrete language.

  Chale-only — the shared `EmakolaWeb.StorefrontComponents` cards are used
  by other themes and must not be restyled. Three rules shape everything
  here:

    * Placeholder-first: the image slot is a concrete panel carrying the
      product's initial and the price stamp, so cards look finished before
      (or without) the photograph. The real image layers over it on arrival.
    * The pasted-flyer tile is the signature — hard black borders with a
      solid offset block shadow, square imagery, uppercase display type.
    * The merchant's primary colour (crimson by default) is the only heat:
      primary CTAs, the cart badge, low-stock callouts, the hero tape strip.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── CSS Variable Injection ──

  @doc """
  Injects theme CSS custom properties as a <style> block. `--chale-display`
  resolves to the merchant's design-token heading font when they picked
  one, falling back to Anton — the theme's poster face.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#DC143C") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#09090B") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#F4F4F5") %>;
        --chale-display: var(--dt-heading-font, 'Anton', 'Archivo', sans-serif);
      }
    </style>
    """
  end

  # ── Top Navigation ──

  @doc """
  Chale's own banner header. Store identity linking home, desktop category
  links, search (a plain link to the products page — no client event to
  crash on), and the cart link carrying the live item count. Sticky so the
  cart stays one tap away on a long scroll.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def chale_nav(assigns) do
    ~H"""
    <header role="banner" class="sticky top-0 z-50 border-b-2 border-zinc-950 bg-white">
      <div class="mx-auto max-w-[1280px] px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between gap-3 sm:h-16">
          <a
            href={store_path(@store.slug, "/")}
            class="flex min-w-0 items-center gap-2.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2"
          >
            <span
              class="flex h-9 w-9 flex-shrink-0 items-center justify-center bg-zinc-950 text-base font-bold uppercase text-white [font-family:var(--chale-display)]"
              aria-hidden="true"
            >
              {String.first(@store.name)}
            </span>
            <span class="truncate text-lg font-bold uppercase tracking-tight text-zinc-950 [font-family:var(--chale-display)] sm:text-xl">
              {@store.name}
            </span>
          </a>

          <nav
            :if={@categories != []}
            class="hidden min-w-0 flex-1 items-center justify-center gap-5 md:flex"
            aria-label="Categories"
          >
            <a
              :for={category <- Enum.take(@categories, 5)}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="whitespace-nowrap text-xs font-bold uppercase tracking-widest text-zinc-600 hover:text-zinc-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              {category.name}
            </a>
          </nav>

          <div class="flex flex-shrink-0 items-center gap-0.5">
            <a
              href={store_path(@store.slug, "/products")}
              aria-label="Search products"
              class="flex h-11 w-11 items-center justify-center text-zinc-600 hover:bg-zinc-100 hover:text-zinc-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 motion-safe:transition-colors"
            >
              <svg
                class="h-[22px] w-[22px]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
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
              aria-label={"Shopping cart, #{@cart_count} items"}
              class="relative flex h-11 w-11 items-center justify-center text-zinc-600 hover:bg-zinc-100 hover:text-zinc-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 motion-safe:transition-colors"
            >
              <svg
                class="h-[22px] w-[22px]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
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
                class="absolute right-0.5 top-0.5 flex h-[18px] min-w-[18px] items-center justify-center bg-store-accent px-1 text-[10px] font-bold leading-none text-white"
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

  # ── Mobile Bottom Navigation ──

  @doc """
  Chale-owned mobile tab bar — Home, Shop, Saved, Cart. Mobile-only; the
  banner nav above carries the desktop cart link.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active, :atom, values: [:home, :shop, :saved, :cart], default: :home

  def chale_bottom_nav(assigns) do
    ~H"""
    <nav
      class="safe-area-inset-bottom fixed inset-x-0 bottom-0 z-40 border-t-2 border-zinc-950 bg-white sm:hidden"
      aria-label="Store"
    >
      <div class="flex h-14 items-center justify-around">
        <a
          href={store_path(@store.slug, "/")}
          aria-current={if @active == :home, do: "page"}
          class={[
            "flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950",
            if(@active == :home, do: "text-zinc-950", else: "text-zinc-400 hover:text-zinc-950")
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
          <span class="text-[0.625rem] font-bold uppercase tracking-wide">Home</span>
        </a>
        <a
          href={store_path(@store.slug, "/products")}
          aria-current={if @active == :shop, do: "page"}
          class={[
            "flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950",
            if(@active == :shop, do: "text-zinc-950", else: "text-zinc-400 hover:text-zinc-950")
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
          <span class="text-[0.625rem] font-bold uppercase tracking-wide">Shop</span>
        </a>
        <a
          href={store_path(@store.slug, "/wishlist")}
          aria-current={if @active == :saved, do: "page"}
          class={[
            "flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950",
            if(@active == :saved, do: "text-zinc-950", else: "text-zinc-400 hover:text-zinc-950")
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
              d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
            />
          </svg>
          <span class="text-[0.625rem] font-bold uppercase tracking-wide">Saved</span>
        </a>
        <a
          href={store_path(@store.slug, "/cart")}
          aria-current={if @active == :cart, do: "page"}
          aria-label={"Cart, #{@cart_count} items"}
          class={[
            "relative flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950",
            if(@active == :cart, do: "text-zinc-950", else: "text-zinc-400 hover:text-zinc-950")
          ]}
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
              class="absolute -right-1.5 -top-1 flex h-4 min-w-4 items-center justify-center bg-store-accent px-0.5 text-[0.5rem] font-bold leading-none text-white"
            >
              {@cart_count}
            </span>
          </span>
          <span class="text-[0.625rem] font-bold uppercase tracking-wide">Cart</span>
        </a>
      </div>
    </nav>
    """
  end

  # ── Footer ──

  @doc """
  Chale's own footer — the black wall under the concrete page. Brand block
  in display type, shop / info / contact columns, payment rails, copyright.
  Email capture is NOT here — the `chale/newsletter` section owns it, so
  the page never carries two subscribe forms. Contact links render only
  when the store actually has them; no invented prose.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :theme, :map, default: %{}

  def footer(assigns) do
    ~H"""
    <%!-- Explicit role: the layout nests theme content inside <main>,
    which strips <footer>'s implicit contentinfo landmark. --%>
    <footer role="contentinfo" class="border-t-2 border-zinc-950 bg-zinc-950 text-white">
      <%!-- Mobile bottom padding clears the fixed chale_bottom_nav tab bar. --%>
      <div class="mx-auto max-w-[1280px] px-4 pb-28 pt-12 sm:px-6 sm:py-16 lg:px-8">
        <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1fr] lg:gap-8">
          <div>
            <a
              href={store_path(@store.slug, "/")}
              class="inline-flex min-h-[44px] items-center text-3xl font-bold uppercase leading-none tracking-tight text-white [font-family:var(--chale-display)] hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 motion-safe:transition-opacity sm:text-4xl"
            >
              {@store.name}
            </a>
            <p :if={@store.description} class="mt-3 max-w-xs text-sm leading-relaxed text-zinc-400">
              {@store.description}
            </p>
          </div>

          <div>
            <h4 class="mb-5 text-xs font-bold uppercase tracking-[0.2em] text-zinc-100">
              Shop
            </h4>
            <ul class="space-y-3">
              <li>
                <.footer_link href={store_path(@store.slug, "/products")}>
                  All products
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
            <h4 class="mb-5 text-xs font-bold uppercase tracking-[0.2em] text-zinc-100">
              Info
            </h4>
            <ul class="space-y-3">
              <li>
                <.footer_link href={store_path(@store.slug, "/about")}>Our story</.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/contact")}>Contact</.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/faq")}>FAQ</.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/policies#shipping")}>
                  Shipping &amp; returns
                </.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/policies#privacy")}>
                  Privacy policy
                </.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/policies#terms")}>
                  Terms of service
                </.footer_link>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="mb-5 text-xs font-bold uppercase tracking-[0.2em] text-zinc-100">
              Get in touch
            </h4>
            <ul class="space-y-3">
              <li :if={Map.get(@store, :whatsapp_number)}>
                <.footer_link href={"https://wa.me/#{@store.whatsapp_number}"}>
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
                <.footer_link href={store_path(@store.slug, "/about")}>About us</.footer_link>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 border-t border-zinc-800 pt-8">
          <div class="flex flex-col items-center justify-between gap-6 sm:flex-row">
            <div class="flex flex-wrap items-center justify-center gap-2">
              <span class="mr-2 text-[10px] font-bold uppercase tracking-[0.2em] text-zinc-500">
                We accept
              </span>
              <span
                :for={rail <- ["MTN MoMo", "Telecel Cash", "Visa", "Mastercard"]}
                class="inline-flex items-center border border-zinc-700 bg-zinc-900 px-2.5 py-1 text-[10px] font-bold tracking-wide text-zinc-200"
              >
                {rail}
              </span>
            </div>
            <div class="flex items-center gap-1.5 text-zinc-500">
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

        <div class="mt-8 flex flex-col items-center justify-between gap-4 border-t border-zinc-800 pt-8 sm:flex-row">
          <p class="text-xs text-zinc-500">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-[10px] text-zinc-500">
            Powered by <span class="font-semibold text-zinc-300">Makola</span>
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
      class="inline-flex min-h-[44px] items-center gap-2 text-sm text-zinc-400 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 motion-safe:transition-colors"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  # ── Cards ──

  @doc """
  Image-free price stamp: display-family typography, tabular numerals, hard
  black border with a solid offset shadow — a hand-stamped tag. Renders
  instantly with zero image bytes. Carries the strikethrough compare-at
  ("was") price when the product is on sale.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :size, :atom, values: [:sm, :lg], default: :sm

  def price_stamp(assigns) do
    assigns = assign(assigns, :compare_at, compare_at_price(assigns.product))

    ~H"""
    <span class={[
      "inline-block border-2 border-zinc-950 bg-white font-bold tabular-nums tracking-tight text-zinc-950",
      "shadow-[3px_3px_0_0_#09090B] [font-family:var(--chale-display)]",
      if(@size == :lg,
        do: "px-4 py-2 text-2xl leading-none sm:text-3xl",
        else: "px-2 py-1 text-[0.8125rem] leading-none"
      )
    ]}>
      {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      <s :if={@compare_at} class="ml-1 text-[0.7em] font-medium text-zinc-500 line-through">
        <span class="sr-only">was</span>
        {Currency.format_price(@compare_at, @store.currency)}
      </s>
    </span>
    """
  end

  @doc """
  Grid product card — the pasted flyer. Square placeholder-first image
  slot with the price stamp at the lower-left; title row with an optional
  quick add-to-cart button (`quick_add` — only for pages whose LiveView
  handles `add_to_cart`).
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :quick_add, :boolean, default: false

  def product_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:sold_out, sold_out?(assigns.product))

    ~H"""
    <div class="group">
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="relative block aspect-square overflow-hidden border-2 border-zinc-950 shadow-[4px_4px_0_0_#09090B] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-transform motion-safe:group-hover:-translate-y-0.5"
      >
        <div
          class="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-zinc-100 to-zinc-300"
          aria-hidden="true"
        >
          <span class="select-none text-7xl font-bold uppercase text-zinc-400 [font-family:var(--chale-display)]">
            {String.first(@product.title)}
          </span>
        </div>
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          width={480}
          height={480}
          class="absolute inset-0 h-full w-full object-cover"
        />
        <div :if={@sold_out} class="absolute inset-0 z-[5] bg-white/60" aria-hidden="true"></div>
        <span
          :if={@sold_out}
          class="absolute right-2 top-3 z-10 -rotate-3 bg-zinc-950 px-2 py-1 text-[0.6875rem] font-bold uppercase tracking-widest text-white"
        >
          Sold out
        </span>
        <div class="absolute bottom-2 left-2 z-10">
          <.price_stamp product={@product} store={@store} />
        </div>
      </a>
      <div class="mt-3 flex items-start justify-between gap-2">
        <a
          href={store_path(@store.slug, "/products/#{@product.slug}")}
          class="min-w-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2"
        >
          <h3 class="truncate text-sm font-bold uppercase tracking-wide text-zinc-950">
            {@product.title}
          </h3>
        </a>
        <button
          :if={@quick_add && !@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="flex h-9 w-9 flex-shrink-0 cursor-pointer items-center justify-center bg-zinc-950 text-white hover:bg-store-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:scale-95"
          aria-label={"Add #{@product.title} to cart"}
        >
          <svg
            class="h-4 w-4"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
        </button>
        <button
          :if={@quick_add && @sold_out}
          type="button"
          disabled
          aria-disabled="true"
          class="flex h-9 w-9 flex-shrink-0 cursor-not-allowed items-center justify-center bg-zinc-200 text-zinc-400"
          aria-label={"#{@product.title} is sold out"}
        >
          <svg
            class="h-4 w-4"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  # ── Data helpers ──

  @doc """
  The compare-at ("was") price to show on a product's price stamp, in
  minor units, or nil. Shown only when the product has a single price
  point (min == max) and its cheapest loaded variant carries a
  compare_at_price above its price. Products whose variants aren't loaded
  show no sale treatment: fail quiet, never crash.
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

  @doc """
  Whether any in-stock variant carries the given option value — "is my
  size still there". Option values with no variant mapping (or products
  whose variants aren't loaded) fail open to available; add_to_cart
  re-checks server-side.
  """
  def option_value_available?(product, vov_map, option_value_id) do
    vov_map = vov_map || %{}

    matching =
      Enum.filter(loaded_variants(product), fn variant ->
        vov_map
        |> Map.get(variant.id, [])
        |> Enum.any?(&(&1.option_value_id == option_value_id))
      end)

    case matching do
      [] -> true
      variants -> Enum.any?(variants, &Emakola.Catalog.Variant.in_stock?/1)
    end
  end

  defp loaded_variants(%{variants: variants}) when is_list(variants), do: variants
  defp loaded_variants(_product), do: []

  @doc """
  True when the product was added within the last 14 days — the honest
  window for a "New" stamp.
  """
  def new_arrival?(product) do
    case Map.get(product, :inserted_at) do
      %DateTime{} = dt -> DateTime.diff(DateTime.utc_now(), dt, :day) <= 14
      %NaiveDateTime{} = ndt -> NaiveDateTime.diff(NaiveDateTime.utc_now(), ndt, :day) <= 14
      _ -> false
    end
  end

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
