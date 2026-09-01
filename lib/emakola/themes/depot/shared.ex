defmodule Emakola.Themes.Depot.Shared do
  @moduledoc """
  Depot theme chrome and helpers — the theme's own nav, mobile tab bar,
  footer, the order-sheet row that is Depot's signature, and the data
  helpers its pages share.

  Depot owns all of its chrome (themes must bring their own nav with a
  desktop-reachable cart link) and reads only fields `Emakola.Catalog`
  really exposes: variant `sku`, `price`, `compare_at_price`,
  `stock_quantity`, `track_inventory`, `position`, `weight_grams`. The
  catalog has no minimum-order-quantity, unit-of-measure, or price-tier
  fields, so Depot surfaces none.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── CSS variable injection ──

  @doc """
  Injects theme CSS custom properties as a <style> block. Placed first
  inside the outermost div of the home page.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#18181B") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#C2410C") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FAFAFA") %>;
      }
    </style>
    """
  end

  # ── Top navigation ──

  @doc """
  Depot's own banner header. Store identity linking home, desktop
  category links, search as a plain link to the products page (no client
  event to crash on), and the cart as a labelled "Order" button carrying
  the live count — for a wholesale buyer the cart is the order pad, so it
  reads as one. Sticky so the order stays one tap away down a long sheet.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def depot_nav(assigns) do
    ~H"""
    <header role="banner" class="sticky top-0 z-50 border-b border-[#E7E5E1] bg-white">
      <div class="mx-auto max-w-[1120px] px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between gap-3 sm:h-16">
          <a
            href={store_path(@store.slug, "/")}
            class="flex min-w-0 items-center gap-2.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2"
          >
            <span
              class="flex h-9 w-9 flex-shrink-0 items-center justify-center bg-zinc-900 text-sm font-bold text-white [font-family:var(--dt-heading-font,inherit)]"
              aria-hidden="true"
            >
              {String.first(@store.name)}
            </span>
            <span class="truncate text-base font-bold tracking-tight text-zinc-900 [font-family:var(--dt-heading-font,inherit)] sm:text-lg">
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
              class="whitespace-nowrap text-sm font-medium text-zinc-600 hover:text-zinc-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              {category.name}
            </a>
          </nav>

          <div class="flex flex-shrink-0 items-center gap-1.5">
            <a
              href={store_path(@store.slug, "/products")}
              aria-label="Search products"
              class="flex h-11 w-11 items-center justify-center text-zinc-600 hover:bg-zinc-100 hover:text-zinc-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 motion-safe:transition-colors"
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
              aria-label={"Your order, #{Emakola.Plural.count(@cart_count, "item")}"}
              class="flex h-11 items-center gap-2 border border-[#E7E5E1] shadow-sm px-3.5 text-sm font-bold text-zinc-900 hover:bg-zinc-900 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              <svg
                class="h-5 w-5"
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
              <span class="hidden sm:inline">Order</span>
              <span
                :if={@cart_count > 0}
                class="flex h-5 min-w-5 items-center justify-center bg-store-accent px-1 text-[11px] font-bold leading-none text-white"
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
  Depot-owned mobile tab bar — Home, Catalogue, Order. Mobile-only by
  design; the banner header keeps the cart reachable on desktop.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active, :atom, values: [:home, :catalogue, :cart], default: :home

  def depot_bottom_nav(assigns) do
    ~H"""
    <nav
      class="safe-area-inset-bottom fixed inset-x-0 bottom-0 z-40 border-t border-[#E7E5E1] bg-white sm:hidden"
      aria-label="Store"
    >
      <div class="flex h-14 items-stretch">
        <.bottom_tab href={store_path(@store.slug, "/")} label="Home" active={@active == :home}>
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
        </.bottom_tab>
        <.bottom_tab
          href={store_path(@store.slug, "/products")}
          label="Catalogue"
          active={@active == :catalogue}
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
              d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM3.75 12h.007v.008H3.75V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm-.375 5.25h.007v.008H3.75v-.008zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
        </.bottom_tab>
        <.bottom_tab
          href={store_path(@store.slug, "/cart")}
          label="Order"
          active={@active == :cart}
          badge={@cart_count}
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
              d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
        </.bottom_tab>
      </div>
    </nav>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :badge, :integer, default: 0
  slot :inner_block, required: true

  defp bottom_tab(assigns) do
    ~H"""
    <a
      href={@href}
      aria-current={@active && "page"}
      aria-label={if @badge > 0, do: "#{@label}, #{Emakola.Plural.count(@badge, "item")}"}
      class={[
        "flex flex-1 flex-col items-center justify-center gap-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-zinc-900",
        if(@active, do: "text-zinc-900", else: "text-zinc-400 hover:text-zinc-900")
      ]}
    >
      <span class="relative">
        {render_slot(@inner_block)}
        <span
          :if={@badge > 0}
          class="absolute -right-1.5 -top-1 flex h-4 min-w-4 items-center justify-center bg-store-accent px-0.5 text-[0.5rem] font-bold leading-none text-white"
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

  # ── Footer ──

  @doc """
  Depot's own footer — ink-dark ledger chrome. Brand block, catalogue and
  company link columns, contact links only when the store has them,
  payment badges, secure-checkout mark, copyright. Email capture is NOT
  here — the depot/newsletter section owns it.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :theme, :map, default: %{}

  def footer(assigns) do
    social_links = get_in(assigns[:theme] || %{}, [:footer, :social_links]) || %{}
    assigns = assign(assigns, :socials, social_urls(social_links))

    ~H"""
    <%!-- Explicit role: the layout nests theme content inside <main>,
    which strips <footer>'s implicit contentinfo landmark. --%>
    <footer role="contentinfo" class="border-t border-[#E7E5E1] bg-zinc-950 text-white">
      <%!-- Mobile bottom padding clears the fixed depot_bottom_nav tab bar. --%>
      <div class="mx-auto max-w-[1120px] px-4 pb-28 pt-14 sm:px-6 sm:py-16 lg:px-8">
        <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1fr] lg:gap-8">
          <div>
            <a
              href={store_path(@store.slug, "/")}
              class="inline-flex min-h-[44px] items-center text-xl font-bold tracking-tight text-white [font-family:var(--dt-heading-font,inherit)] hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 motion-safe:transition-opacity"
            >
              {@store.name}
            </a>
            <p
              :if={@store.description}
              class="mt-3 max-w-xs text-sm leading-relaxed text-zinc-400"
            >
              {@store.description}
            </p>
            <div :if={@socials != []} class="mt-4 flex items-center gap-3">
              <.social_icon :for={{label, url, icon} <- @socials} url={url} label={label} icon={icon} />
            </div>
          </div>

          <div>
            <h4 class="mb-5 font-mono text-xs font-semibold uppercase tracking-widest text-zinc-100">
              Catalogue
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
            <h4 class="mb-5 font-mono text-xs font-semibold uppercase tracking-widest text-zinc-100">
              Company
            </h4>
            <ul class="space-y-3">
              <li>
                <.footer_link href={store_path(@store.slug, "/about")}>About us</.footer_link>
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
            <h4 class="mb-5 font-mono text-xs font-semibold uppercase tracking-widest text-zinc-100">
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
                <.footer_link href={store_path(@store.slug, "/about")}>Our story</.footer_link>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 border-t border-zinc-800 pt-8">
          <div class="flex flex-col items-center justify-between gap-6 sm:flex-row">
            <div class="flex flex-wrap items-center justify-center gap-2">
              <span class="mr-2 font-mono text-[10px] uppercase tracking-widest text-zinc-500">
                We accept
              </span>
              <span class={[payment_badge_classes(), "bg-[#FFCC00] text-black"]}>MTN MoMo</span>
              <span class={[payment_badge_classes(), "bg-[#E60000] text-white"]}>Telecel Cash</span>
              <span class={[payment_badge_classes(), "bg-[#1A1F71] text-white"]}>Visa</span>
              <span class={[payment_badge_classes(), "bg-[#FF5F00] text-white"]}>Mastercard</span>
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
              <span class="font-mono text-[10px] uppercase tracking-widest">Secure checkout</span>
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

  attr :url, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true

  defp social_icon(assigns) do
    ~H"""
    <a
      href={@url}
      class="flex h-11 w-11 items-center justify-center text-zinc-400 hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 motion-safe:transition-colors"
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

  defp payment_badge_classes,
    do: "inline-flex items-center px-2.5 py-1 text-[10px] font-bold tracking-wide"

  # ── Order-sheet row (the signature) ──

  @doc """
  One line of the order sheet: item, SKU, stock on hand, price, action.
  Single-variant items quick-add one unit through the home page's real
  `add_to_cart` handler; multi-variant items route to the product page —
  blind-adding an arbitrary variant would betray a trade buyer's intent.
  Sold-out rows say so and offer no binding. Products whose variants
  aren't loaded fail quiet: the add fails open and the handler re-checks
  stock server-side.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :index, :integer, default: nil

  def order_row(assigns) do
    lead = lead_variant(assigns.product)

    assigns =
      assigns
      |> assign(:lead, lead)
      |> assign(:sku, sku_label(lead))
      |> assign(:multi, variant_count(assigns.product) > 1)
      |> assign(:sold_out, sold_out?(assigns.product))
      |> assign(:compare_at, compare_at_price(assigns.product))
      |> assign(:image, first_image(assigns.product))
      |> assign(:line_no, line_number(assigns[:index]))

    ~H"""
    <tr class="group border-b border-[#E7E5E1] last:border-b-0 hover:bg-[#FAF9F7] motion-safe:transition-colors">
      <%!-- The line number is the manifest's own structure: these rows are a
      numbered sequence on a sheet, not a decorative list. The rule down the
      left is Depot's signal colour, lit on the line under the cursor. --%>
      <td class="w-10 border-l-2 border-transparent py-3 pl-3 pr-0 align-middle font-mono text-[0.6875rem] tabular-nums text-[#A8A29E] group-hover:border-[#C2410C] sm:pl-4">
        {@line_no}
      </td>
      <td class="py-3 pl-3 pr-3 sm:pl-4">
        <div class="flex items-center gap-3">
          <%!-- Identification aid beside the title it repeats: decorative to a
          screen reader, which already hears the product name on the next line. --%>
          <.optimized_image
            :if={@image}
            src={@image}
            alt=""
            width={96}
            height={96}
            class="h-11 w-11 flex-shrink-0 border border-[#E7E5E1] object-cover"
          />
          <span
            :if={!@image}
            aria-hidden="true"
            class="flex h-11 w-11 flex-shrink-0 items-center justify-center border border-[#E7E5E1] bg-[#F1EFEA] font-mono text-sm font-semibold text-[#A8A29E]"
          >
            {String.first(@product.title)}
          </span>
          <div class="min-w-0">
            <a
              href={store_path(@store.slug, "/products/#{@product.slug}")}
              class="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#C2410C] focus-visible:ring-offset-2"
            >
              <span class="block text-sm font-semibold leading-snug text-zinc-900">
                {@product.title}
              </span>
            </a>
            <span class="mt-1 flex items-center gap-2.5 sm:hidden">
              <span class="font-mono text-[0.6875rem] text-zinc-500">{@sku}</span>
              <.stock_indicator variant={@lead} />
            </span>
          </div>
        </div>
      </td>
      <td class="hidden px-3 py-3 font-mono text-xs text-zinc-500 sm:table-cell">{@sku}</td>
      <td class="hidden px-3 py-3 md:table-cell">
        <.stock_indicator variant={@lead} />
      </td>
      <td class="px-3 py-3 text-right">
        <span class="text-sm font-bold tabular-nums text-zinc-900">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </span>
        <s :if={@compare_at} class="ml-1 text-xs font-medium tabular-nums text-zinc-400 line-through">
          <span class="sr-only">was</span>
          {Currency.format_price(@compare_at, @store.currency)}
        </s>
      </td>
      <td class="py-3 pl-3 pr-4 text-right sm:pr-5">
        <%= cond do %>
          <% @multi -> %>
            <a
              href={store_path(@store.slug, "/products/#{@product.slug}")}
              aria-label={"View options for #{@product.title}"}
              class="inline-flex h-9 items-center border border-zinc-300 px-3 text-xs font-bold text-zinc-800 hover:border-zinc-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              Options
            </a>
          <% @sold_out -> %>
            <button
              type="button"
              disabled
              aria-disabled="true"
              class="inline-flex h-9 cursor-not-allowed items-center border border-[#E7E5E1] bg-zinc-100 px-3 text-xs font-bold text-zinc-400"
            >
              Out
            </button>
          <% true -> %>
            <button
              type="button"
              phx-click="add_to_cart"
              phx-value-product-id={@product.id}
              aria-label={"Add #{@product.title} to your order"}
              class="inline-flex h-9 cursor-pointer items-center gap-1 bg-zinc-900 px-3.5 text-xs font-bold text-white hover:bg-[#C2410C] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#C2410C] focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:scale-95"
            >
              <svg
                class="h-3.5 w-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Add
            </button>
        <% end %>
      </td>
    </tr>
    """
  end

  # Manifest line numbers are 1-based and zero-padded: 01, 02 … 10.
  defp line_number(index) when is_integer(index) and index >= 0 do
    index |> Kernel.+(1) |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  defp line_number(_index), do: nil

  @doc """
  Stock on hand as a square status pip plus honest label, straight from
  the variant's real `track_inventory`/`stock_quantity` fields. Unknown
  (variants not loaded, or none) renders a quiet dash — never a guess.
  """
  attr :variant, :map, default: nil

  def stock_indicator(assigns) do
    assigns = assign(assigns, :state, stock_state(assigns.variant))

    ~H"""
    <%= case @state do %>
      <% :unknown -> %>
        <span class="text-xs text-zinc-400">&mdash;</span>
      <% :untracked -> %>
        <span class="inline-flex items-center gap-1.5 text-xs font-semibold text-emerald-700">
          <span class="h-1.5 w-1.5 bg-emerald-500" aria-hidden="true"></span> Available
        </span>
      <% {:in_stock, qty} -> %>
        <span class="inline-flex items-center gap-1.5 text-xs font-semibold tabular-nums text-emerald-700">
          <span class="h-1.5 w-1.5 bg-emerald-500" aria-hidden="true"></span> {qty} in stock
        </span>
      <% {:low, qty} -> %>
        <span class="inline-flex items-center gap-1.5 text-xs font-semibold tabular-nums text-amber-700">
          <span class="h-1.5 w-1.5 bg-amber-500" aria-hidden="true"></span> {qty} left
        </span>
      <% :out -> %>
        <span class="inline-flex items-center gap-1.5 text-xs font-semibold text-red-700">
          <span class="h-1.5 w-1.5 bg-red-500" aria-hidden="true"></span> Out of stock
        </span>
    <% end %>
    """
  end

  # ── Data helpers ──

  @doc """
  The variant the home page's `add_to_cart` handler will actually add —
  first by position — so the row's SKU and stock describe the unit the
  buyer gets. Nil when variants aren't loaded.
  """
  def lead_variant(%{variants: variants}) when is_list(variants) do
    variants |> Enum.sort_by(& &1.position) |> List.first()
  end

  def lead_variant(_product), do: nil

  @doc """
  How many purchase options the product carries. Prefers loaded variants,
  falls back to the `variant_count` aggregate when a list read loaded it,
  and fails quiet to 0 otherwise (`Ash.NotLoaded` matches neither guard).
  """
  def variant_count(%{variants: variants}) when is_list(variants), do: length(variants)
  def variant_count(%{variant_count: count}) when is_integer(count), do: count
  def variant_count(_product), do: 0

  @doc """
  True when every loaded variant is out of stock —
  `Emakola.Catalog.Variant.in_stock?/1` is the single purchasability rule.
  Products whose variants aren't loaded fail open to purchasable: the
  `add_to_cart` handler re-checks stock server-side.
  """
  def sold_out?(product) do
    case loaded_variants(product) do
      [_ | _] = variants -> not Enum.any?(variants, &Emakola.Catalog.Variant.in_stock?/1)
      _ -> false
    end
  end

  @doc """
  Stock state from the variant's real fields: `:untracked` (made to
  order / supplier-fulfilled — always purchasable), `{:in_stock, qty}`,
  `{:low, qty}` under 5 (the platform's low-stock line), `:out`, or
  `:unknown` when there is no variant to read.
  """
  def stock_state(nil), do: :unknown
  def stock_state(%{track_inventory: false}), do: :untracked

  def stock_state(%{stock_quantity: qty}) when is_integer(qty) do
    cond do
      qty <= 0 -> :out
      qty < 5 -> {:low, qty}
      true -> {:in_stock, qty}
    end
  end

  def stock_state(_variant), do: :unknown

  @doc """
  The compare-at ("was") price for a single-price-point product, in minor
  units, or nil. A strikethrough next to a price *range* would be
  ambiguous, and unloaded variants fail quiet.
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

  defp loaded_variants(%{variants: variants}) when is_list(variants), do: variants
  defp loaded_variants(_product), do: []

  defp sku_label(%{sku: sku}) when is_binary(sku) and sku != "", do: sku
  defp sku_label(_variant), do: "—"

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
  Unit weight from the variant's real `weight_grams`, formatted with
  integer arithmetic only — "500 g", "2 kg", "2 kg 500 g". Nil when the
  merchant didn't record one.
  """
  def format_weight(%{weight_grams: grams}) when is_integer(grams) and grams > 0 do
    cond do
      grams < 1000 -> "#{grams} g"
      rem(grams, 1000) == 0 -> "#{div(grams, 1000)} kg"
      true -> "#{div(grams, 1000)} kg #{rem(grams, 1000)} g"
    end
  end

  def format_weight(_variant), do: nil

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
          message = "Hi, I'd like to order #{product_title} from #{Map.get(store, :name)}"
          "https://wa.me/#{digits}?text=#{URI.encode_www_form(message)}"
        end

      _ ->
        nil
    end
  end
end
