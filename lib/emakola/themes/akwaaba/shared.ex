defmodule Emakola.Themes.Akwaaba.Shared do
  @moduledoc """
  Akwaaba chrome — the floating pill nav, the ink footer, and the cards.

  Akwaaba is the photo-led theme: warm orange ground, Playfair display serif,
  rounded everything, cards that float over their panels. Where the other themes
  let typography carry the page, Akwaaba lets the merchant's photographs carry
  it and keeps the type in a supporting role.

  The nav has two faces. On the home page it is an **overlay**: a white pill bar
  floating inside the hero's orange panel, the way a shopfront sign sits on the
  awning. Everywhere else it is a solid bar on white. Both faces carry a cart
  link that is reachable on desktop — the mobile bottom bar is `sm:hidden`, and
  a theme whose only cart link lives there strands desktop shoppers with no path
  to checkout. That exact bug shipped on Market and Vibrant; it does not ship
  again.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  @doc "Theme CSS custom properties."
  attr :theme, :map, default: %{}

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --akwaaba-display: var(--dt-heading-font, 'Playfair Display', Georgia, serif);
        --akwaaba-body: var(--dt-body-font, 'Archivo', system-ui, sans-serif);
        --akwaaba-sun: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#F0531F") %>;
        --akwaaba-amber: #F5A524;
        --akwaaba-ink: #101010;
      }
    </style>
    """
  end

  @doc """
  The pill nav. `overlay={true}` floats it inside the hero panel (home page);
  otherwise it renders solid on white.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :overlay, :boolean, default: false

  def akwaaba_nav(assigns) do
    ~H"""
    <header
      role="banner"
      class={[
        "w-full [font-family:var(--akwaaba-body)]",
        @overlay && "absolute inset-x-0 top-0 z-40",
        !@overlay && "sticky top-0 z-40 border-b border-zinc-200 bg-white/95 backdrop-blur"
      ]}
    >
      <div class="mx-auto flex max-w-[1320px] items-center gap-4 px-5 py-4 sm:px-10 sm:py-6">
        <a
          href={store_path(@store.slug, "/")}
          class={[
            "flex min-w-0 items-center gap-2 text-xl font-semibold tracking-tight [font-family:var(--akwaaba-display)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 sm:text-2xl",
            @overlay && "text-white focus-visible:ring-white",
            !@overlay &&
              "text-[color:var(--akwaaba-ink)] focus-visible:ring-[color:var(--akwaaba-sun)]"
          ]}
        >
          <span class="truncate">{@store.name}</span>
        </a>

        <%!-- The pill: white bar, categories inside it. Hidden on mobile, where
        the bottom bar takes over. --%>
        <nav
          :if={@categories != []}
          aria-label="Categories"
          class="mx-auto hidden items-center gap-1 rounded-full bg-white p-1.5 shadow-sm md:flex"
        >
          <a
            :for={category <- Enum.take(@categories, 5)}
            href={store_path(@store.slug, "/category/#{category.slug}")}
            class="rounded-full px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] motion-safe:transition-colors"
          >
            {category.name}
          </a>
        </nav>

        <div class="ml-auto flex items-center gap-2 sm:gap-3">
          <a
            href={store_path(@store.slug, "/products")}
            aria-label="Search products"
            class="flex h-10 w-10 items-center justify-center rounded-full bg-white text-zinc-900 shadow-sm hover:bg-zinc-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2 motion-safe:transition-colors sm:h-11 sm:w-11"
          >
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M21 21l-4.35-4.35M17 10a7 7 0 11-14 0 7 7 0 0114 0z"
              />
            </svg>
          </a>

          <a
            href={store_path(@store.slug, "/cart")}
            aria-label={"Shopping cart, #{Emakola.Plural.count(@cart_count, "item")}"}
            class="relative flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--akwaaba-ink)] text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2 motion-safe:transition-opacity sm:h-11 sm:w-11"
          >
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3 3h2l.4 2M7 13h10l3-8H6.4M7 13L5.4 5M7 13l-2 5h13m-8 3a1 1 0 11-2 0 1 1 0 012 0zm8 0a1 1 0 11-2 0 1 1 0 012 0z"
              />
            </svg>
            <span
              :if={@cart_count > 0}
              class="absolute -right-1 -top-1 flex h-5 min-w-[1.25rem] items-center justify-center rounded-full bg-[color:var(--akwaaba-amber)] px-1 text-[0.6875rem] font-bold tabular-nums text-[color:var(--akwaaba-ink)]"
            >
              {@cart_count}
            </span>
          </a>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  Product card: rounded photo, quick-add, and an honest sale badge.

  `show_add={false}` renders a browse-only card for the product list, whose
  LiveView has no `add_to_cart` handler — a phx-click with no handler is a crash,
  not a no-op.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :show_add, :boolean, default: true

  def product_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:compare_at, compare_at_price(assigns.product))
      |> assign(:sold_out, sold_out?(assigns.product))

    ~H"""
    <div class="group [font-family:var(--akwaaba-body)]">
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="relative block aspect-[4/5] overflow-hidden rounded-3xl bg-[#F6F4F1] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2"
      >
        <.photo_or_initial image={@image} title={@product.title} />

        <span
          :if={@compare_at}
          class="absolute left-3 top-3 z-10 rounded-full bg-[color:var(--akwaaba-sun)] px-3 py-1 text-[0.6875rem] font-bold uppercase tracking-wide text-white"
        >
          Sale
        </span>
        <span
          :if={@sold_out}
          class="absolute left-3 top-3 z-10 rounded-full bg-[color:var(--akwaaba-ink)]/90 px-3 py-1 text-[0.6875rem] font-bold uppercase tracking-wide text-white"
        >
          Sold out
        </span>
      </a>

      <div class="mt-3 flex items-start justify-between gap-3">
        <div class="min-w-0">
          <a
            href={store_path(@store.slug, "/products/#{@product.slug}")}
            class="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2"
          >
            <h3 class="truncate text-base font-medium text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
              {@product.title}
            </h3>
          </a>
          <p class="mt-0.5 flex items-baseline gap-1.5 text-sm font-semibold tabular-nums text-[color:var(--akwaaba-ink)]">
            {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
            <s :if={@compare_at} class="text-xs font-medium text-zinc-400">
              <span class="sr-only">was</span>
              {Currency.format_price(@compare_at, @store.currency)}
            </s>
          </p>
        </div>

        <button
          :if={@show_add && !@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="flex h-10 w-10 flex-shrink-0 cursor-pointer items-center justify-center rounded-full bg-[color:var(--akwaaba-ink)] text-white hover:bg-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:scale-95"
        >
          <span class="sr-only">Add {@product.title} to cart</span>
          <svg
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2.5"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 5v14M5 12h14" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  @doc """
  A photograph, or — with none — a warm tile carrying a quiet bag pictogram.
  Never the piece's initial: a letter means nothing to a buyer who reads
  slowly. The tile is the panel marked `data-placeholder="product"`.

  The tile sits *beneath* the image rather than instead of it, so a real photo
  simply covers it and nothing has to choose between the two. Both layers are
  `absolute inset-0`, so the caller must supply the positioned container.
  """
  attr :image, :string, default: nil
  attr :title, :string, required: true
  attr :sizes, :list, default: [640, 800]

  def photo_or_initial(assigns) do
    ~H"""
    <div
      class="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-[#FBEDE6] to-[#F2DCD0]"
      data-placeholder="product"
      aria-hidden="true"
    >
      <svg
        class="h-14 w-14 text-[#E0B39C]"
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
    </div>
    <.optimized_image
      :if={@image}
      src={@image}
      alt={@title}
      width={Enum.at(@sizes, 0)}
      height={Enum.at(@sizes, 1)}
      class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-500 motion-safe:group-hover:scale-[1.04]"
    />
    """
  end

  @doc "Ink footer, with the store's name oversized along the bottom edge."
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :theme, :map, default: %{}

  def footer(assigns) do
    ~H"""
    <footer
      role="contentinfo"
      class="relative overflow-hidden bg-[color:var(--akwaaba-ink)] pb-28 pt-16 text-white [font-family:var(--akwaaba-body)] sm:pb-36"
    >
      <div class="mx-auto max-w-[1320px] px-5 sm:px-10">
        <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <p class="text-2xl font-semibold [font-family:var(--akwaaba-display)]">{@store.name}</p>
            <p :if={@store.description} class="mt-3 max-w-xs text-sm leading-relaxed text-white/60">
              {@store.description}
            </p>
          </div>

          <div>
            <p class="text-[0.6875rem] font-bold uppercase tracking-[0.2em] text-white/40">Shop</p>
            <ul class="mt-4 space-y-3 text-sm">
              <li>
                <a
                  href={store_path(@store.slug, "/products")}
                  class="text-white/70 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
                >
                  All products
                </a>
              </li>
              <li :for={category <- Enum.take(@categories, 5)}>
                <a
                  href={store_path(@store.slug, "/category/#{category.slug}")}
                  class="text-white/70 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
                >
                  {category.name}
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p class="text-[0.6875rem] font-bold uppercase tracking-[0.2em] text-white/40">Company</p>
            <ul class="mt-4 space-y-3 text-sm">
              <li :for={
                {label, path} <- [
                  {"About", "/about"},
                  {"Contact", "/contact"},
                  {"FAQ", "/faq"},
                  {"Delivery & returns", "/policies"}
                ]
              }>
                <a
                  href={store_path(@store.slug, path)}
                  class="text-white/70 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
                >
                  {label}
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p class="text-[0.6875rem] font-bold uppercase tracking-[0.2em] text-white/40">
              We accept
            </p>
            <ul class="mt-4 flex flex-wrap gap-2">
              <li
                :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}
                class="rounded-full border border-white/15 px-3 py-1.5 text-xs font-medium text-white/70"
              >
                {rail}
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 flex flex-col gap-2 border-t border-white/10 pt-6 text-xs text-white/40 sm:flex-row sm:items-center sm:justify-between">
          <p>&copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.</p>
          <p>Powered by <span class="font-semibold text-white/70">Makola</span></p>
        </div>
      </div>

      <%!-- The wordmark, oversized and running off the bottom edge — the shop's
      name as a graphic, clipped by the footer. Decorative: the name is already
      announced above. --%>
      <p
        aria-hidden="true"
        class="pointer-events-none absolute -bottom-4 left-0 w-full select-none truncate px-2 text-center text-[18vw] font-semibold leading-[0.75] text-white/[0.07] [font-family:var(--akwaaba-display)] sm:-bottom-8"
      >
        {@store.name}
      </p>
    </footer>
    """
  end

  @doc "Mobile bottom bar. `sm:hidden` — the nav above carries desktop."
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active, :atom, default: :home

  def bottom_nav(assigns) do
    ~H"""
    <nav
      aria-label="Quick links"
      class="safe-area-inset-bottom fixed inset-x-0 bottom-0 z-40 border-t border-zinc-200 bg-white/95 backdrop-blur sm:hidden"
    >
      <ul class="grid grid-cols-4">
        <li :for={
          {label, path, key} <- [
            {"Home", "/", :home},
            {"Shop", "/products", :shop},
            {"Saved", "/wishlist", :wishlist},
            {"Cart", "/cart", :cart}
          ]
        }>
          <a
            href={store_path(@store.slug, path)}
            aria-current={@active == key && "page"}
            class={[
              "flex min-h-[56px] flex-col items-center justify-center gap-0.5 text-[0.6875rem] font-medium",
              @active == key && "text-[color:var(--akwaaba-sun)]",
              @active != key && "text-zinc-500"
            ]}
          >
            {label}
            <span
              :if={key == :cart and @cart_count > 0}
              class="rounded-full bg-[color:var(--akwaaba-sun)] px-1.5 text-[0.625rem] font-bold tabular-nums text-white"
            >
              {@cart_count}
            </span>
          </a>
        </li>
      </ul>
    </nav>
    """
  end

  @doc "First image URL for a product, or nil."
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc "The image at `index`, falling back to the first."
  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

  @doc """
  The struck-through price, but only when it is real.

  A sale badge that is not backed by an actual `compare_at_price` is a lie told
  to the shopper on the merchant's behalf, so this returns nil unless a variant
  genuinely costs less than it used to.
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

  @doc "True when every variant is out of stock."
  def sold_out?(product) do
    case loaded_variants(product) do
      [_ | _] = variants -> not Enum.any?(variants, &Emakola.Catalog.Variant.in_stock?/1)
      _ -> false
    end
  end

  defp loaded_variants(%{variants: variants}) when is_list(variants), do: variants
  defp loaded_variants(_product), do: []
end
