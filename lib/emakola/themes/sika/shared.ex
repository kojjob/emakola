defmodule Emakola.Themes.Sika.Shared do
  @moduledoc """
  Sika theme chrome and hallmark components.

  Owns the theme's nav, mobile bar and footer (gate: every theme brings its
  own nav with a desktop-reachable cart link), plus the hallmark language
  the whole theme is built from:

  - `makers_mark/1` — square stamp carrying the store's initial, the way a
    goldsmith punches a maker's mark.
  - `hallmark/1` — small punched chip for true facts only (payment rails,
    a piece's reference, availability).
  - `caught_light/1` — a 1px gradient rule; the only gold on the page,
    like light catching a polished edge.
  - `tray/1` — the velvet-tray image placeholder: deep touchstone green
    with an assay-ring monogram, finished before any image byte arrives.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── CSS variable injection ──

  @doc """
  Injects theme CSS custom properties as a <style> block. Place first
  inside the outermost element of the home page.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#1F332C") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#C2A15B") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FAF9F7") %>;
      }
    </style>
    """
  end

  # ── Hallmark language ──

  @doc """
  The caught-light rule — a hairline that brightens to gold at its centre,
  the only place gold appears as colour. Decorative.
  """
  attr :class, :any, default: "w-16"

  def caught_light(assigns) do
    ~H"""
    <div
      aria-hidden="true"
      class={["h-px bg-gradient-to-r from-transparent via-[#C2A15B] to-transparent", @class]}
    >
    </div>
    """
  end

  @doc """
  The maker's mark — a square hairline stamp carrying the store's initial.
  Decorative (the adjacent text carries the name).
  """
  attr :name, :string, required: true
  attr :tone, :atom, values: [:ink, :light], default: :ink
  attr :class, :any, default: nil

  def makers_mark(assigns) do
    ~H"""
    <span
      aria-hidden="true"
      class={[
        "flex select-none items-center justify-center border",
        "[font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]",
        @tone == :ink && "border-[#C2A15B]/60 text-[#1F332C]",
        @tone == :light && "border-[#C2A15B]/60 text-[#EFE9DA]",
        @class
      ]}
    >
      {String.first(@name)}
    </span>
    """
  end

  @doc """
  A punched hallmark chip. Carries true facts only — a payment rail, a
  piece's reference, availability. Square, like an assay stamp.
  """
  attr :tone, :atom, values: [:light, :dark], default: :light
  slot :inner_block, required: true

  def hallmark(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-1.5 text-[0.625rem] font-semibold uppercase tracking-[0.18em]",
      @tone == :light && "border border-[#E8E3D9] bg-white text-[#6E675C]",
      @tone == :dark && "border border-white/15 bg-white/5 text-[#D8D2C4]"
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  The velvet-tray image placeholder: touchstone green with a faint sheen
  and a quiet bag pictogram in caught gold inside a hairline assay ring,
  marked `data-placeholder`. Never the piece's initial — a letter means
  nothing to a buyer who reads slowly. Absolute-positioned to fill its
  (relative) parent; a real image layers over it on arrival.
  """
  def tray(assigns) do
    ~H"""
    <div class="absolute inset-0 bg-[#1F332C]" data-placeholder="product" aria-hidden="true">
      <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_30%_25%,rgba(194,161,91,0.18),transparent_65%)]">
      </div>
      <span class="absolute inset-0 flex items-center justify-center">
        <span class="flex h-16 w-16 items-center justify-center rounded-full border border-[#C2A15B]/50 text-[#C2A15B]">
          <svg
            class="h-7 w-7"
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
      </span>
    </div>
    """
  end

  # ── Cards ──

  @doc """
  Collection card: vitrine-framed image (velvet tray first), name in the
  display face, price stated plainly. A link, never a quick-add — pieces
  are viewed, not grabbed.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def piece_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:sold_out, sold_out?(assigns.product))

    ~H"""
    <div>
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        aria-label={"View #{@product.title}"}
        class="group block border border-[#E8E3D9] bg-white p-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 sm:p-3"
      >
        <div class="relative aspect-[4/5] overflow-hidden">
          <.tray />
          <.optimized_image
            :if={@image}
            src={@image}
            alt={@product.title}
            width={480}
            height={600}
            class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-700 motion-safe:group-hover:scale-[1.02]"
          />
          <span
            :if={@sold_out}
            class="absolute right-2.5 top-2.5 inline-flex border border-white/20 bg-[#211D16]/85 px-2.5 py-1.5 text-[0.625rem] font-semibold uppercase tracking-[0.18em] text-white"
          >
            Sold out
          </span>
        </div>
      </a>
      <div class="mt-4 text-center">
        <h3 class={[
          "text-lg text-[#211D16]",
          "[font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]"
        ]}>
          <a
            href={store_path(@store.slug, "/products/#{@product.slug}")}
            class="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2"
          >
            {@product.title}
          </a>
        </h3>
        <p class="mt-1 text-sm tabular-nums text-[#6E675C]">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
      </div>
    </div>
    """
  end

  # ── Top navigation ──

  @doc """
  Sika's banner header — maker's-mark wordmark linking home, quiet
  category links, search as a plain link, and the cart with its live
  count. Sticky and desktop-visible, so the cart is always one step away.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def sika_nav(assigns) do
    ~H"""
    <header
      role="banner"
      class="sticky top-0 z-50 border-b border-[#E8E3D9] bg-[#FAF9F7]/95 backdrop-blur"
    >
      <div class="mx-auto max-w-[1200px] px-4 sm:px-6 lg:px-8">
        <div class="flex h-16 items-center justify-between gap-3">
          <a
            href={store_path(@store.slug, "/")}
            class="flex min-w-0 items-center gap-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2"
          >
            <.makers_mark name={@store.name} class="h-9 w-9 flex-shrink-0 text-base" />
            <span class={[
              "truncate text-lg tracking-[0.06em] text-[#211D16]",
              "[font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]"
            ]}>
              {@store.name}
            </span>
          </a>

          <nav
            :if={@categories != []}
            class="hidden min-w-0 flex-1 items-center justify-center gap-7 md:flex"
            aria-label="Categories"
          >
            <a
              :for={category <- Enum.take(@categories, 4)}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="whitespace-nowrap text-[0.6875rem] font-semibold uppercase tracking-[0.18em] text-[#6E675C] hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              {category.name}
            </a>
          </nav>

          <div class="flex flex-shrink-0 items-center gap-1">
            <a
              href={store_path(@store.slug, "/products")}
              aria-label="Search products"
              class="flex h-11 w-11 items-center justify-center text-[#6E675C] hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] motion-safe:transition-colors"
            >
              <svg
                class="h-[21px] w-[21px]"
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
              class="relative flex h-11 w-11 items-center justify-center text-[#6E675C] hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] motion-safe:transition-colors"
            >
              <svg
                class="h-[21px] w-[21px]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.6"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007z"
                />
              </svg>
              <span
                :if={@cart_count > 0}
                class="absolute -right-0.5 top-0.5 flex h-[18px] min-w-[18px] items-center justify-center bg-[#1F332C] px-1 text-[10px] font-semibold leading-none text-white"
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
  Sika-owned mobile tab bar — Home, Collection, Saved, Cart on porcelain.
  Mobile-only; the banner nav carries the desktop cart link.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active, :atom, values: [:home, :collection], default: :home

  def sika_bottom_nav(assigns) do
    ~H"""
    <nav
      class="safe-area-inset-bottom fixed inset-x-0 bottom-0 z-40 border-t border-[#E8E3D9] bg-[#FAF9F7] sm:hidden"
      aria-label="Store"
    >
      <div class="flex h-14 items-center justify-around">
        <a
          href={store_path(@store.slug, "/")}
          aria-current={@active == :home && "page"}
          class={[
            "flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16]",
            if(@active == :home, do: "text-[#211D16]", else: "text-[#8C857A] hover:text-[#211D16]")
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
          <span class="text-[0.625rem] font-semibold">Home</span>
        </a>
        <a
          href={store_path(@store.slug, "/products")}
          aria-current={@active == :collection && "page"}
          class={[
            "flex flex-col items-center gap-0.5 px-3 py-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16]",
            if(@active == :collection,
              do: "text-[#211D16]",
              else: "text-[#8C857A] hover:text-[#211D16]"
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
          <span class="text-[0.625rem] font-medium">Collection</span>
        </a>
        <a
          href={store_path(@store.slug, "/wishlist")}
          class="flex flex-col items-center gap-0.5 px-3 py-1 text-[#8C857A] hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16]"
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
          aria-label={"Cart, #{Emakola.Plural.count(@cart_count, "item")}"}
          class="relative flex flex-col items-center gap-0.5 px-3 py-1 text-[#8C857A] hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16]"
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
                d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007z"
              />
            </svg>
            <span
              :if={@cart_count > 0}
              class="absolute -right-1.5 -top-1 flex h-4 min-w-4 items-center justify-center bg-[#1F332C] px-0.5 text-[0.5rem] font-bold leading-none text-white"
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
  Sika's footer — the velvet tray the collection rests on. Touchstone
  green, centred identity, quiet link columns, payment rails as hallmark
  stamps. Capture belongs to the newsletter section, not here.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer role="contentinfo" class="bg-[#1F332C] text-[#C9CFC4]">
      <div class="mx-auto max-w-[1200px] px-4 py-14 sm:px-6 lg:px-8">
        <div class="flex flex-col items-center text-center">
          <.makers_mark name={@store.name} tone={:light} class="h-12 w-12 text-xl" />
          <p class={[
            "mt-4 text-xl tracking-[0.06em] text-[#F2EEE3]",
            "[font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]"
          ]}>
            {@store.name}
          </p>
          <.caught_light class="mt-5 w-24" />
          <p
            :if={@store.description}
            class="mt-5 max-w-md text-sm leading-relaxed text-[#A9B4A8]"
          >
            {@store.description}
          </p>
        </div>

        <div class="mt-12 grid grid-cols-2 gap-10 text-center sm:grid-cols-3 sm:text-left">
          <div>
            <p class="text-[0.625rem] font-semibold uppercase tracking-[0.25em] text-[#8C9A8C]">
              The collection
            </p>
            <ul class="mt-4 space-y-2.5">
              <li>
                <.footer_link href={store_path(@store.slug, "/products")}>All pieces</.footer_link>
              </li>
              <li :for={category <- Enum.take(@categories, 4)}>
                <.footer_link href={store_path(@store.slug, "/category/#{category.slug}")}>
                  {category.name}
                </.footer_link>
              </li>
            </ul>
          </div>
          <div>
            <p class="text-[0.625rem] font-semibold uppercase tracking-[0.25em] text-[#8C9A8C]">
              The shop
            </p>
            <ul class="mt-4 space-y-2.5">
              <li>
                <.footer_link href={store_path(@store.slug, "/about")}>Our story</.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/contact")}>Contact</.footer_link>
              </li>
              <li><.footer_link href={store_path(@store.slug, "/faq")}>FAQ</.footer_link></li>
              <li>
                <.footer_link href={store_path(@store.slug, "/policies#shipping")}>
                  Delivery &amp; returns
                </.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/policies#privacy")}>
                  Privacy
                </.footer_link>
              </li>
            </ul>
          </div>
          <div class="col-span-2 sm:col-span-1">
            <p class="text-[0.625rem] font-semibold uppercase tracking-[0.25em] text-[#8C9A8C]">
              Speak with us
            </p>
            <ul class="mt-4 space-y-2.5">
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
            </ul>
          </div>
        </div>

        <div class="mt-12 border-t border-white/10 pt-8 text-center">
          <p class="text-[0.625rem] font-semibold uppercase tracking-[0.25em] text-[#8C9A8C]">
            We accept
          </p>
          <ul
            class="mt-4 flex flex-wrap items-center justify-center gap-2"
            aria-label="Payment methods"
          >
            <li :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}>
              <.hallmark tone={:dark}>{rail}</.hallmark>
            </li>
          </ul>
          <p class="mt-8 text-xs text-[#8C9A8C]">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="mt-1.5 text-xs text-[#8C9A8C]">
            Powered by <span class="font-semibold text-[#C2A15B]">Makola</span>
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
      class="text-sm text-[#C9CFC4] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#C2A15B] motion-safe:transition-colors"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  # ── Data helpers ──

  @doc """
  A trimmed non-empty string, or nil. For settings fallback chains.
  """
  def present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  def present(_value), do: nil

  @doc """
  Extract the first image URL from a product's images association.
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
  """
  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

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

  defp loaded_variants(%{variants: variants}) when is_list(variants), do: variants
  defp loaded_variants(_product), do: []

  @doc """
  wa.me link to the store's WhatsApp number prefilled with the piece's
  title, or nil when the store has no number.
  """
  def whatsapp_link(store, product_title) do
    case Map.get(store, :whatsapp_number) do
      number when is_binary(number) ->
        digits = String.replace(number, ~r/\D/, "")

        if digits == "" do
          nil
        else
          message = "Hello, I'd like to ask about #{product_title} from #{Map.get(store, :name)}"
          "https://wa.me/#{digits}?text=#{URI.encode_www_form(message)}"
        end

      _ ->
        nil
    end
  end
end
