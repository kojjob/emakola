defmodule Emakola.Themes.Ntoma.Shared do
  @moduledoc """
  Ntoma theme chrome and card components — nav, footer, price tag, product
  cards, and image helpers shared by the home, product list, and product
  detail renderers.

  Ntoma ("cloth" in Twi) is the mainstream fashion theme: terracotta and
  amber on unbleached calico, oversized Fraunces display capitals, and a
  woven selvedge strip as the placeholder glyph language. Three rules shape
  every component here:

    * Type-first: the page must be composed before any photograph arrives.
      Placeholder panels carry the product's serif initial and a legible
      price tag, so cards look finished with zero image bytes.
    * The price tag is a garment label — cream ground, stitched (dashed)
      border, serif tabular numerals. It stays umber-on-cream so it reads
      no matter which primary colour the merchant picks.
    * The merchant's primary colour deploys with restraint: primary CTAs
      and the newsletter button, via `bg-store-accent`. Everything else is
      Ntoma's own cloth palette.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # Selvedge strip pattern — terracotta / gold / umber / calico blocks with
  # a woven rhythm. Literal class strings so Tailwind's scanner sees them.
  @woven_pattern [
    {"bg-[#9E3B14]", "flex-[3]"},
    {"bg-[#E0A32E]", "flex-[1]"},
    {"bg-[#2B1708]", "flex-[2]"},
    {"bg-[#F0E3CE]", "flex-[1]"},
    {"bg-[#9E3B14]", "flex-[1]"},
    {"bg-[#E0A32E]", "flex-[2]"},
    {"bg-[#2B1708]", "flex-[1]"},
    {"bg-[#9E3B14]", "flex-[2]"},
    {"bg-[#F0E3CE]", "flex-[1]"},
    {"bg-[#E0A32E]", "flex-[3]"}
  ]

  # ── CSS Variable Injection ──

  @doc """
  Injects theme CSS custom properties into the page as a <style> block.
  Place this as the first element inside the outermost div of the home page.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#9E3B14") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#E0A32E") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FAF4EA") %>;
      }
    </style>
    """
  end

  # ── Decorative selvedge ──

  @doc """
  The woven selvedge strip — Ntoma's zero-byte decorative signature.
  A row of terracotta/gold/umber/calico blocks; purely decorative.
  """
  attr :class, :string, default: "h-1.5"

  def woven_strip(assigns) do
    assigns = assign(assigns, :pattern, @woven_pattern)

    ~H"""
    <div class={["flex w-full", @class]} aria-hidden="true">
      <span :for={{color, weight} <- @pattern} class={["h-full", color, weight]}></span>
    </div>
    """
  end

  # ── Top Navigation ──

  @doc """
  Ntoma's own banner header — calico ground, serif wordmark, and the cart
  link carrying the live item count. Search is a plain link to the products
  page (no client event to crash on). Sticky so the cart stays one tap away
  on a long phone scroll; the cart link here is what keeps checkout
  reachable on desktop, where the mobile tab bar is hidden.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def ntoma_nav(assigns) do
    ~H"""
    <header
      role="banner"
      class="sticky top-0 z-50 border-b border-[#E6D5B8] bg-[#FAF4EA]/95 backdrop-blur"
    >
      <div class="mx-auto max-w-[1280px] px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between gap-3 sm:h-16">
          <a
            href={store_path(@store.slug, "/")}
            class="flex min-w-0 items-center gap-2.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 focus-visible:ring-offset-[#FAF4EA]"
          >
            <span
              class="flex h-9 w-9 flex-shrink-0 items-center justify-center border border-[#E6D5B8] bg-[#F0E3CE] text-base font-semibold text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]"
              aria-hidden="true"
            >
              {String.first(@store.name)}
            </span>
            <span class="truncate text-base font-semibold uppercase tracking-[0.08em] text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-lg">
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
              class="whitespace-nowrap text-[0.8125rem] font-semibold uppercase tracking-[0.1em] text-[#7A6248] hover:text-[#2B1708] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] motion-safe:transition-colors"
            >
              {category.name}
            </a>
          </nav>

          <div class="flex flex-shrink-0 items-center gap-0.5">
            <a
              href={store_path(@store.slug, "/products")}
              aria-label="Search products"
              class="flex h-11 w-11 items-center justify-center text-[#7A6248] hover:bg-[#F0E3CE] hover:text-[#2B1708] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] motion-safe:transition-colors"
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
              class="relative flex h-11 w-11 items-center justify-center text-[#7A6248] hover:bg-[#F0E3CE] hover:text-[#2B1708] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] motion-safe:transition-colors"
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
                class="absolute right-0.5 top-0.5 flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-[#2B1708] px-1 text-[10px] font-bold leading-none text-[#FAF4EA]"
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
  Ntoma's mobile tab bar — Home, Search, Saved, Cart on the calico ground.
  Mobile-only chrome (`sm:hidden`); the banner header above carries the
  desktop cart link.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active, :atom, default: :home

  def ntoma_bottom_nav(assigns) do
    ~H"""
    <nav
      class="safe-area-inset-bottom fixed inset-x-0 bottom-0 z-40 border-t border-[#E6D5B8] bg-[#FAF4EA] sm:hidden"
      aria-label="Store"
    >
      <div class="flex h-14 items-center justify-around">
        <.bottom_tab
          href={store_path(@store.slug, "/")}
          label="Home"
          active={@active == :home}
          icon="home"
        />
        <.bottom_tab
          href={store_path(@store.slug, "/products")}
          label="Search"
          active={@active == :search}
          icon="search"
        />
        <.bottom_tab
          href={store_path(@store.slug, "/wishlist")}
          label="Saved"
          active={@active == :saved}
          icon="heart"
        />
        <.bottom_tab
          href={store_path(@store.slug, "/cart")}
          label="Cart"
          active={@active == :cart}
          icon="bag"
          badge={@cart_count}
        />
      </div>
    </nav>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  attr :badge, :integer, default: 0

  defp bottom_tab(assigns) do
    ~H"""
    <a
      href={@href}
      aria-current={@active && "page"}
      aria-label={if @icon == "bag", do: "Cart, #{@badge} items", else: nil}
      class={[
        "flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708]",
        if(@active, do: "text-[#2B1708]", else: "text-[#A08863] hover:text-[#2B1708]")
      ]}
    >
      <span class="relative">
        <.tab_icon name={@icon} />
        <span
          :if={@icon == "bag" && @badge > 0}
          class="absolute -right-1.5 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-[#2B1708] px-0.5 text-[0.5rem] font-bold leading-none text-[#FAF4EA]"
        >
          {@badge}
        </span>
      </span>
      <span class={["text-[0.625rem]", if(@active, do: "font-semibold", else: "font-medium")]}>
        {@label}
      </span>
    </a>
    """
  end

  attr :name, :string, required: true

  defp tab_icon(%{name: "home"} = assigns) do
    ~H"""
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
    """
  end

  defp tab_icon(%{name: "search"} = assigns) do
    ~H"""
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
    """
  end

  defp tab_icon(%{name: "heart"} = assigns) do
    ~H"""
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
    """
  end

  defp tab_icon(%{name: "bag"} = assigns) do
    ~H"""
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
    """
  end

  # ── Footer ──

  @doc """
  Ntoma's own footer — deep umber cloth under the calico page, selvedge
  strip on top. Content parity with the Market footer it models: brand
  block, shop / company / contact columns, payment badges, secure-checkout
  mark, copyright. Email capture is NOT here — the `ntoma/newsletter`
  section owns it, so the page never carries two subscribe forms. Contact
  links and the brand description render only when the store has them —
  no invented prose.
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

    assigns = assign(assigns, :company_links, company_links)

    ~H"""
    <footer role="contentinfo" class="bg-[#26130B] text-[#F5E9D6]">
      <.woven_strip class="h-1.5" />
      <%!-- Mobile bottom padding clears the fixed ntoma_bottom_nav tab bar. --%>
      <div class="mx-auto max-w-[1280px] px-4 pb-28 pt-14 sm:px-6 sm:py-20 lg:px-8">
        <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1fr] lg:gap-8">
          <div>
            <a
              href={store_path(@store.slug, "/")}
              class="inline-flex min-h-[44px] items-center text-xl font-semibold uppercase tracking-[0.08em] text-[#F5E9D6] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F5E9D6]/70 motion-safe:transition-opacity"
            >
              {@store.name}
            </a>
            <p
              :if={@store.description}
              class="mt-3 max-w-xs text-sm leading-relaxed text-[#BFA888]"
            >
              {@store.description}
            </p>
          </div>

          <div>
            <h4 class="mb-5 text-xs font-semibold uppercase tracking-widest text-[#E0A32E]">
              Shop
            </h4>
            <ul class="space-y-3">
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
            <h4 class="mb-5 text-xs font-semibold uppercase tracking-widest text-[#E0A32E]">
              Company
            </h4>
            <ul class="space-y-3">
              <li :for={link <- @company_links}>
                <.footer_link :if={Map.get(link, :url)} href={Map.get(link, :url)}>
                  {Map.get(link, :label)}
                </.footer_link>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="mb-5 text-xs font-semibold uppercase tracking-widest text-[#E0A32E]">
              Get in Touch
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
                <.footer_link href={store_path(@store.slug, "/about")}>
                  About Us
                </.footer_link>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 border-t border-[#3D2413] pt-8">
          <div class="flex flex-col items-center justify-between gap-6 sm:flex-row">
            <div class="flex flex-wrap items-center justify-center gap-2">
              <span class="mr-2 text-[10px] uppercase tracking-widest text-[#8A7156]">
                We Accept
              </span>
              <span
                :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}
                class="inline-flex items-center border border-[#3D2413] bg-[#301A0E] px-2.5 py-1 text-[10px] font-bold tracking-wide text-[#F5E9D6]"
              >
                {rail}
              </span>
            </div>
            <div class="flex items-center gap-1.5 text-[#8A7156]">
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
              <span class="text-[10px] uppercase tracking-widest">Secure Checkout</span>
            </div>
          </div>
        </div>

        <div class="mt-8 flex flex-col items-center justify-between gap-4 border-t border-[#3D2413] pt-8 sm:flex-row">
          <p class="text-xs text-[#8A7156]">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-[10px] text-[#8A7156]">
            Powered by <span class="font-semibold text-[#BFA888]">Makola</span>
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
      class="inline-flex min-h-[44px] items-center gap-2 text-sm text-[#BFA888] hover:text-[#F5E9D6] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F5E9D6]/70 motion-safe:transition-colors"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  # ── Cards ──

  @doc """
  The garment-label price tag: cream ground, stitched (dashed) border,
  serif tabular numerals. Renders instantly with zero image bytes and stays
  umber-on-cream so it survives any merchant primary colour. Carries the
  strikethrough compare-at ("was") price when the product is on sale — see
  `compare_at_price/1` for when that applies.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :size, :atom, values: [:sm, :lg], default: :sm

  def price_tag(assigns) do
    assigns = assign(assigns, :compare_at, compare_at_price(assigns.product))

    ~H"""
    <span class={[
      "inline-block border border-dashed border-[#B98F55] bg-[#FFFBF2] font-semibold tabular-nums tracking-tight text-[#2B1708]",
      "[font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]",
      if(@size == :lg,
        do: "px-4 py-2.5 text-2xl leading-none sm:text-3xl",
        else: "px-2.5 py-1.5 text-[0.8125rem] leading-none"
      )
    ]}>
      {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      <s :if={@compare_at} class="ml-0.5 text-[0.75em] font-medium text-[#9C8465] line-through">
        <span class="sr-only">was</span>
        {Currency.format_price(@compare_at, @store.currency)}
      </s>
    </span>
    """
  end

  @doc """
  The calico panel a card shows when a piece has no photograph: a tonal ground
  crossed by warp and weft hairlines, carrying the piece's serif initial.

  Ntoma is the cloth theme, so its empty state is woven rather than blank. This
  is not decoration for its own sake — a merchant's very first look at their own
  storefront is an image-less one, and a grid of flat swatches reads as broken
  when it is merely empty.

  It sits beneath the photograph (`absolute inset-0`) rather than instead of it,
  so a real image simply covers it; nothing has to decide between the two.
  """
  attr :initial, :string, required: true
  attr :scale, :atom, default: :grid, values: [:grid, :feature]

  def weave_tile(assigns) do
    ~H"""
    <div
      class="absolute inset-0 bg-gradient-to-br from-[#F5EBDA] via-[#F0E3CE] to-[#E4D0AF]"
      aria-hidden="true"
    >
      <div class="absolute inset-0 bg-[repeating-linear-gradient(90deg,_rgba(43,23,8,0.055)_0px,_rgba(43,23,8,0.055)_1px,_transparent_1px,_transparent_7px)]">
      </div>
      <div class="absolute inset-0 bg-[repeating-linear-gradient(0deg,_rgba(43,23,8,0.04)_0px,_rgba(43,23,8,0.04)_1px,_transparent_1px,_transparent_7px)]">
      </div>
      <div class="absolute inset-0 flex items-center justify-center">
        <span class={[
          "select-none font-semibold text-[#C6A671] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]",
          @scale == :feature && "text-9xl",
          @scale == :grid && "text-7xl"
        ]}>
          {@initial}
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Grid product card: portrait frame, placeholder-first — the calico panel
  carries the piece's serif initial and the price tag, so the card is
  finished before (or without) the photograph. `show_add={false}` renders a
  browse-only card for pages whose LiveView has no `add_to_cart` handler
  (the product list).
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :show_add, :boolean, default: true

  def product_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:sold_out, sold_out?(assigns.product))

    ~H"""
    <div class="group">
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="relative block aspect-[3/4] overflow-hidden border border-[#E6D5B8] shadow-sm focus-visible:outline-none motion-safe:transition-shadow motion-safe:group-hover:shadow-md focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2"
      >
        <.weave_tile initial={String.first(@product.title)} />
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          width={480}
          height={640}
          class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-500 motion-safe:group-hover:scale-[1.03]"
        />
        <div :if={@sold_out} class="absolute inset-0 z-[5] bg-[#FAF4EA]/60" aria-hidden="true"></div>
        <span
          :if={@sold_out}
          class="absolute right-2.5 top-2.5 z-10 bg-[#2B1708]/90 px-2.5 py-1 text-[0.6875rem] font-bold uppercase tracking-wide text-[#FAF4EA]"
        >
          Sold out
        </span>
        <div class="absolute bottom-2.5 left-2.5 z-10">
          <.price_tag product={@product} store={@store} />
        </div>
      </a>
      <div class="mt-3 flex items-center justify-between gap-2">
        <a
          href={store_path(@store.slug, "/products/#{@product.slug}")}
          class="min-w-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2"
        >
          <h3 class="truncate text-[0.9375rem] font-medium leading-snug text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]">
            {@product.title}
          </h3>
        </a>
        <button
          :if={@show_add && !@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="flex h-9 w-9 flex-shrink-0 cursor-pointer items-center justify-center bg-[#2B1708] text-[#FAF4EA] hover:bg-store-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:scale-95"
          aria-label={"Add #{@product.title} to cart"}
        >
          <svg
            class="h-4 w-4"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
        </button>
        <button
          :if={@show_add && @sold_out}
          type="button"
          disabled
          aria-disabled="true"
          class="flex h-9 w-9 flex-shrink-0 cursor-not-allowed items-center justify-center bg-[#E6D5B8] text-[#A08863]"
          aria-label={"#{@product.title} is sold out"}
        >
          <svg
            class="h-4 w-4"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
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

  @doc """
  Editorial featured card: photograph (placeholder-first) beside a calm
  text panel — eyebrow, serif title, description, oversized price tag, and
  the page's primary CTA.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :eyebrow, :string, default: "Featured"

  def featured_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:sold_out, sold_out?(assigns.product))

    ~H"""
    <div class="overflow-hidden border border-[#E6D5B8] bg-[#FFFBF2] md:grid md:grid-cols-2">
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="relative block aspect-[4/3] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#2B1708] md:aspect-auto md:h-full md:min-h-[360px]"
        aria-label={"View #{@product.title}"}
      >
        <.weave_tile initial={String.first(@product.title)} scale={:feature} />
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          width={640}
          height={480}
          class="absolute inset-0 h-full w-full object-cover"
        />
        <div :if={@sold_out} class="absolute inset-0 z-[5] bg-[#FAF4EA]/60" aria-hidden="true"></div>
        <span
          :if={@sold_out}
          class="absolute right-4 top-4 z-10 bg-[#2B1708]/90 px-3 py-1.5 text-xs font-bold uppercase tracking-wide text-[#FAF4EA]"
        >
          Sold out
        </span>
        <div class="absolute bottom-4 left-4 z-10">
          <.price_tag product={@product} store={@store} size={:lg} />
        </div>
      </a>
      <div class="p-6 sm:p-8 md:flex md:flex-col md:justify-center md:p-10">
        <span class="mb-3 block text-[0.6875rem] font-bold uppercase tracking-[0.24em] text-[#B97C10]">
          {@eyebrow}
        </span>
        <h2 class="mb-2 text-2xl font-semibold leading-tight text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-3xl">
          <a
            href={store_path(@store.slug, "/products/#{@product.slug}")}
            class="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2"
          >
            {@product.title}
          </a>
        </h2>
        <p
          :if={@product.description}
          class="mb-5 text-sm leading-relaxed text-[#7A6248] line-clamp-3"
        >
          {@product.description}
        </p>
        <button
          :if={!@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="mt-2 flex w-full cursor-pointer items-center justify-center bg-store-accent px-8 py-4 text-sm font-bold uppercase tracking-[0.14em] leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.99] sm:w-auto"
        >
          Add to cart
        </button>
        <button
          :if={@sold_out}
          type="button"
          disabled
          aria-disabled="true"
          class="mt-2 flex w-full cursor-not-allowed items-center justify-center bg-[#E6D5B8] px-8 py-4 text-sm font-bold uppercase tracking-[0.14em] leading-none text-[#A08863] sm:w-auto"
        >
          Sold out
        </button>
      </div>
    </div>
    """
  end

  # ── Product helpers ──

  @doc """
  The compare-at ("was") price to show on a product's price tag, in minor
  units, or nil.

  Shown only when the product has a single price point (min == max) and its
  cheapest loaded variant carries a compare_at_price above its price —
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
  Extract image URL from a category, if available.
  """
  def category_image(category) do
    if Map.has_key?(category, :image_url) do
      category.image_url
    else
      nil
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
