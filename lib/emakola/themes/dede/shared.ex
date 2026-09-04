defmodule Emakola.Themes.Dede.Shared do
  @moduledoc """
  Shared chrome and helpers for the Dede theme — the chop-bar menu board.

  Dede is built for cooked-food sellers whose customers order on a phone,
  hungry, at lunchtime. Three rules shape everything here:

    * The menu board is the design: dish name, price on a dotted leader,
      and availability render instantly with zero image bytes. Photos are
      garnish that layer in late, never the skeleton the page waits for.
    * WhatsApp is a first-class order path — it sits in the banner nav, the
      mobile tab bar, and beside every add-to-order action when the store
      has a number.
    * On the dark board, controls are chalk (cream on bottle green) so the
      design survives any accent hue the merchant picks; the merchant's
      colour lives on the paper areas instead.

  Palette: paper `#FAF5EA`, board `#1B2E23`, chalk `#F3EDDF`, chalk-dim
  `#A8BAA5`, ink `#26211A`, ink-dim `#6B6355`.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── CSS variable injection ──

  @doc """
  Injects theme CSS custom properties. Place first inside the home page's
  outermost div (list/detail pages inherit the layout's baseline vars).
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#8C2F0D") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#1B2E23") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FAF5EA") %>;
      }
    </style>
    """
  end

  # ── Banner nav ──

  @doc """
  Dede's own banner header on all three pages. Store identity linking home,
  desktop category links, search as a plain link to the menu page (no client
  event to crash on), WhatsApp when the store has a number, and the cart
  link carrying the live count — reachable on desktop, not just in the
  mobile tab bar.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def dede_nav(assigns) do
    assigns = assign(assigns, :whatsapp, whatsapp_link(assigns.store))

    ~H"""
    <header
      role="banner"
      class="sticky top-0 z-50 border-b-2 border-[#26211A]/10 bg-[#FAF5EA]/95 backdrop-blur"
    >
      <div class="mx-auto max-w-[1100px] px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between gap-3 sm:h-16">
          <a
            href={store_path(@store.slug, "/")}
            class="flex min-w-0 items-center gap-2.5 rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2"
          >
            <span
              class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg bg-[#1B2E23] text-base text-[#F3EDDF] uppercase [font-family:var(--dt-heading-font,'Anton',sans-serif)]"
              aria-hidden="true"
            >
              {String.first(@store.name)}
            </span>
            <span class="truncate text-lg uppercase tracking-wide text-[#26211A] [font-family:var(--dt-heading-font,'Anton',sans-serif)] sm:text-xl">
              {@store.name}
            </span>
          </a>

          <nav
            :if={@categories != []}
            class="hidden min-w-0 flex-1 items-center justify-center gap-5 md:flex"
            aria-label="Categories"
          >
            <a
              :for={category <- Enum.take(@categories, 4)}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="whitespace-nowrap rounded text-sm font-semibold text-[#6B6355] hover:text-[#26211A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              {category.name}
            </a>
          </nav>

          <div class="flex flex-shrink-0 items-center gap-0.5">
            <a
              href={store_path(@store.slug, "/products")}
              aria-label="Search the shop"
              class="flex h-11 w-11 items-center justify-center rounded-full text-[#6B6355] hover:bg-[#26211A]/5 hover:text-[#26211A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] motion-safe:transition-colors"
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
              :if={@whatsapp}
              href={@whatsapp}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="Order on WhatsApp"
              class="flex h-11 w-11 items-center justify-center rounded-full text-whatsapp hover:bg-whatsapp/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] motion-safe:transition-colors"
            >
              <svg
                class="h-[22px] w-[22px]"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d={whatsapp_glyph()} />
              </svg>
            </a>
            <a
              href={store_path(@store.slug, "/cart")}
              aria-label={"Cart, #{Emakola.Plural.count(@cart_count, "item")}"}
              class="relative flex h-11 w-11 items-center justify-center rounded-full text-[#6B6355] hover:bg-[#26211A]/5 hover:text-[#26211A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] motion-safe:transition-colors"
            >
              <svg
                class="h-[22px] w-[22px]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.8"
                aria-hidden="true"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d={cart_glyph()} />
              </svg>
              <span
                :if={@cart_count > 0}
                class="absolute right-0.5 top-0.5 flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-[#26211A] px-1 text-[10px] font-bold leading-none text-[#F3EDDF]"
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

  # ── Mobile tab bar ──

  @doc """
  Board-green mobile tab bar: Home, Menu, WhatsApp (when the store has a
  number — ordering lives under the thumb), Cart. Mobile-only chrome; the
  banner nav above keeps the cart reachable on desktop.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def dede_bottom_nav(assigns) do
    assigns = assign(assigns, :whatsapp, whatsapp_link(assigns.store))

    ~H"""
    <nav
      class="safe-area-inset-bottom fixed inset-x-0 bottom-0 z-40 border-t-2 border-[#F3EDDF]/10 bg-[#1B2E23] sm:hidden"
      aria-label="Store"
    >
      <div class="flex h-16 items-center justify-around">
        <a
          href={store_path(@store.slug, "/")}
          aria-current="page"
          class="flex flex-col items-center gap-0.5 rounded px-3 py-1 text-[#F3EDDF] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF]"
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
          class="flex flex-col items-center gap-0.5 rounded px-3 py-1 text-[#A8BAA5] hover:text-[#F3EDDF] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF]"
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
          <span class="text-[0.625rem] font-medium">Menu</span>
        </a>
        <a
          :if={@whatsapp}
          href={@whatsapp}
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Order on WhatsApp"
          class="flex flex-col items-center gap-0.5 rounded px-3 py-1 text-[#A8BAA5] hover:text-[#F3EDDF] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF]"
        >
          <span class="flex h-6 w-6 items-center justify-center rounded-full bg-whatsapp text-white">
            <svg class="h-4 w-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d={whatsapp_glyph()} />
            </svg>
          </span>
          <span class="text-[0.625rem] font-medium">WhatsApp</span>
        </a>
        <a
          href={store_path(@store.slug, "/cart")}
          class="relative flex flex-col items-center gap-0.5 rounded px-3 py-1 text-[#A8BAA5] hover:text-[#F3EDDF] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF]"
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
              <path stroke-linecap="round" stroke-linejoin="round" d={cart_glyph()} />
            </svg>
            <span
              :if={@cart_count > 0}
              class="absolute -right-1.5 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-[#F3EDDF] px-0.5 text-[0.5rem] font-bold leading-none text-[#1B2E23]"
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

  # ── Menu row — the signature component ──

  @doc """
  One dish on the board: name in signboard type, dotted leader to the price
  in tabular numerals, optional one-line description and photo peek, and a
  48px chalk add-to-order button. Sold out is unmissable — struck name and
  a chalk stamp — but the dish stays on the board.

  Everything legible before (or without) a single image byte.

  `quick_add` must be false on pages whose LiveView has no
  `add_to_cart` handler taking a product-id payload — that's only the
  store home (`StoreLive`). The list LiveView has no such handler at all,
  and the detail LiveView's ignores the payload (it adds the page's own
  dish), so both render rows as plain links to the dish page.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :quick_add, :boolean, default: false
  attr :id, :string, default: nil

  def menu_row(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:sold_out, sold_out?(assigns.product))

    ~H"""
    <li id={@id} class={["flex items-center gap-3 py-3.5", @sold_out && "opacity-70"]}>
      <.optimized_image
        :if={@image}
        src={@image}
        alt={@product.title}
        width={56}
        height={56}
        class="h-14 w-14 flex-shrink-0 rounded-full border-2 border-[#F3EDDF]/15 object-cover"
      />
      <.dish_placeholder :if={!@image} class="h-14 w-14" />
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="min-w-0 flex-1 rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF] focus-visible:ring-offset-2 focus-visible:ring-offset-[#1B2E23]"
      >
        <span class="flex items-baseline gap-x-3">
          <span class={[
            "text-lg uppercase leading-tight tracking-wide text-[#F3EDDF]",
            "[font-family:var(--dt-heading-font,'Anton',sans-serif)]",
            @sold_out && "line-through decoration-[#F3EDDF]/60 decoration-2"
          ]}>
            {@product.title}
          </span>
          <span
            class="min-w-[1.5rem] flex-1 self-center border-b-2 border-dotted border-[#F3EDDF]/25"
            aria-hidden="true"
          >
          </span>
          <span class="whitespace-nowrap text-base font-bold tabular-nums text-[#F3EDDF]">
            {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
          </span>
        </span>
        <p :if={@product.description} class="mt-0.5 truncate pr-2 text-xs text-[#A8BAA5]">
          {@product.description}
        </p>
      </a>
      <button
        :if={@quick_add and !@sold_out}
        type="button"
        phx-click="add_to_cart"
        phx-value-product-id={@product.id}
        aria-label={"Add #{@product.title} to your order"}
        class="flex h-12 w-12 flex-shrink-0 cursor-pointer items-center justify-center rounded-full bg-[#F3EDDF] text-[#1B2E23] hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF] focus-visible:ring-offset-2 focus-visible:ring-offset-[#1B2E23] motion-safe:transition-colors motion-safe:active:scale-95"
      >
        <svg
          class="h-5 w-5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2.5"
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
      </button>
      <span
        :if={!@quick_add and !@sold_out}
        class="flex h-12 w-12 flex-shrink-0 items-center justify-center text-[#A8BAA5]"
        aria-hidden="true"
      >
        <svg
          class="h-5 w-5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
        </svg>
      </span>
      <span
        :if={@sold_out}
        class="flex-shrink-0 -rotate-3 rounded border-2 border-[#F3EDDF]/50 px-2 py-1 text-[0.625rem] font-bold uppercase tracking-[0.15em] text-[#F3EDDF]/90"
      >
        Sold out
      </span>
    </li>
    """
  end

  # ── Footer ──

  @doc """
  Dede's own footer — the deep end of the board. Menu and info links,
  contact details only when the store really has them, the payment rails
  the platform actually supports, and the store's identity. Explicit
  contentinfo role: the layout nests theme content inside `<main>`, which
  strips `<footer>`'s implicit landmark.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer role="contentinfo" class="bg-[#14231B] text-[#F3EDDF]">
      <%!-- Mobile bottom padding clears the fixed tab bar. --%>
      <div class="mx-auto max-w-[1100px] px-4 pb-28 pt-12 sm:px-6 sm:py-16 lg:px-8">
        <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1fr] lg:gap-8">
          <div>
            <a
              href={store_path(@store.slug, "/")}
              class="inline-flex min-h-[44px] items-center rounded text-xl uppercase tracking-wide [font-family:var(--dt-heading-font,'Anton',sans-serif)] hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF]/70 motion-safe:transition-opacity"
            >
              {@store.name}
            </a>
            <p
              :if={@store.description}
              class="mt-3 max-w-xs text-sm leading-relaxed text-[#A8BAA5]"
            >
              {@store.description}
            </p>
          </div>

          <div>
            <h4 class="mb-4 text-xs font-semibold uppercase tracking-widest text-[#F3EDDF]">
              Menu
            </h4>
            <ul class="space-y-2">
              <li>
                <.footer_link href={store_path(@store.slug, "/products")}>
                  Full menu
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
            <h4 class="mb-4 text-xs font-semibold uppercase tracking-widest text-[#F3EDDF]">
              The Kitchen
            </h4>
            <ul class="space-y-2">
              <li>
                <.footer_link href={store_path(@store.slug, "/about")}>About</.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/contact")}>Contact</.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/faq")}>FAQ</.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/policies")}>
                  Delivery &amp; policies
                </.footer_link>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="mb-4 text-xs font-semibold uppercase tracking-widest text-[#F3EDDF]">
              Get in Touch
            </h4>
            <ul class="space-y-2">
              <li :if={whatsapp_link(@store)}>
                <.footer_link href={whatsapp_link(@store)}>
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path d={whatsapp_glyph()} />
                  </svg>
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
            </ul>
          </div>
        </div>

        <div class="mt-10 border-t border-[#F3EDDF]/15 pt-6">
          <p class="mb-3 text-[10px] font-semibold uppercase tracking-[0.2em] text-[#A8BAA5]">
            We Accept
          </p>
          <ul class="flex flex-wrap items-center gap-2" aria-label="Payment methods">
            <li
              :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}
              class="inline-flex items-center rounded border border-[#F3EDDF]/25 px-2.5 py-1 text-[11px] font-bold tracking-wide text-[#F3EDDF]/90"
            >
              {rail}
            </li>
          </ul>
        </div>

        <div class="mt-8 flex flex-col items-start justify-between gap-3 border-t border-[#F3EDDF]/15 pt-6 sm:flex-row sm:items-center">
          <p class="text-xs text-[#A8BAA5]">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-[10px] text-[#A8BAA5]">
            Powered by <span class="font-semibold text-[#F3EDDF]">Makola</span>
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
      class="inline-flex min-h-[44px] items-center gap-2 rounded text-sm text-[#A8BAA5] hover:text-[#F3EDDF] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF]/70 motion-safe:transition-colors"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  # ── Data helpers ──

  @doc """
  wa.me link to the store's WhatsApp number, or nil when the store has no
  usable number. With a dish title the prefilled message names the dish;
  without one it opens a general order. The message is percent-encoded
  (spaces as %20, `&` as %26) so nothing truncates it.
  """
  def whatsapp_link(store, product_title \\ nil) do
    case Map.get(store, :whatsapp_number) do
      number when is_binary(number) ->
        digits = String.replace(number, ~r/\D/, "")

        if digits == "" do
          nil
        else
          message =
            if product_title,
              do: "Hi! I'd like to order #{product_title} from #{Map.get(store, :name)}",
              else: "Hi! I'd like to place an order from #{Map.get(store, :name)}"

          "https://wa.me/#{digits}?text=#{URI.encode(message, &URI.char_unreserved?/1)}"
        end

      _ ->
        nil
    end
  end

  @doc """
  The round photo slot a dish shows when it has no photograph: a quiet bag
  pictogram in chalk on the board's ground, marked `data-placeholder`.
  Never the dish's initial — a letter means nothing to a buyer who reads
  slowly.
  """
  attr :class, :string, default: nil

  def dish_placeholder(assigns) do
    ~H"""
    <span
      class={[
        "flex flex-shrink-0 items-center justify-center rounded-full border-2 border-[#F3EDDF]/15 bg-[#F3EDDF]/10 text-[#A8BAA5]",
        @class
      ]}
      data-placeholder="product"
      aria-hidden="true"
    >
      <svg
        class="h-[45%] w-[45%]"
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
    </span>
    """
  end

  @doc """
  True when every loaded variant is out of stock —
  `Emakola.Catalog.Variant.in_stock?/1` is the single purchasability rule.
  Products whose variants aren't loaded (or that have none) fail open to
  orderable: the `add_to_cart` handler re-checks stock server-side.
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
  Today's special: the first available dish, or nil when every dish is
  sold out — a sold-out dish never headlines.
  """
  def special(products), do: Enum.find(products, &(!sold_out?(&1)))

  @doc """
  The dishes chalked on the board: every product except today's special,
  which the special section already carries. When nothing is available
  the whole menu stays on the board, struck through.
  """
  def board(products) do
    case special(products) do
      nil -> products
      special -> Enum.reject(products, &(&1.id == special.id))
    end
  end

  @doc """
  First image URL from a product's images — thumbnail_url, then url, else nil.
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc """
  Image at a specific index — medium_url, then url, falling back to the
  first image.
  """
  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

  @doc false
  def whatsapp_glyph do
    "M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"
  end

  @doc false
  def cart_glyph do
    "M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
  end
end
