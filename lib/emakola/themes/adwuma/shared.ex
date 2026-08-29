defmodule Emakola.Themes.Adwuma.Shared do
  @moduledoc """
  Adwuma's chrome and repeated pieces: `:root` styles, nav, footer, product
  card, mobile bottom bar.

  The pure card helpers (`first_image/1`, `compare_at_price/1`, `sold_out?/1`,
  `photo_or_initial/1`) are reused from `Emakola.Themes.Akwaaba.Shared` rather
  than copied. `compare_at_price/1` in particular exists to stop a sale badge
  being shown without a real `compare_at_price` behind it, and a second copy is
  a second thing to drift into telling that lie. Cross-theme reuse is already
  the house pattern — every theme's About renders through
  `DefaultRenderers.About`.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Akwaaba.Shared, as: Cards
  alias EmakolaWeb.Helpers.Currency

  attr :theme, :map, default: %{}

  @doc """
  The theme's `:root` custom properties.

  Every merchant-controlled colour goes through `CssColor.safe_css_color/2` —
  these values are interpolated into a `<style>` block, so an unsanitised one
  is CSS injection. The mint is a literal because it is not merchant-settable.

  Fonts resolve through `--dt-*` first so Design Studio's typography tokens win
  when a merchant has set them, and Adwuma's own faces win when they have not.
  """
  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --adw-lavender: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#6E56CF") %>;
        --adw-peach: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#F2B8A2") %>;
        --adw-mint: #A9DFC8;
        --adw-ink: #14131A;
        --adw-muted: #6F6C7A;
        --adw-bg: #FBFBFA;
        --adw-rule: #E7E5EC;
        --adw-display: var(--dt-heading-font, 'Sora', system-ui, sans-serif);
        --adw-body: var(--dt-body-font, 'Plus Jakarta Sans', system-ui, sans-serif);
        --adw-mesh:
          radial-gradient(60% 55% at 18% 12%, color-mix(in srgb, var(--adw-peach) 55%, transparent) 0%, transparent 70%),
          radial-gradient(55% 50% at 82% 8%, color-mix(in srgb, var(--adw-lavender) 38%, transparent) 0%, transparent 72%),
          radial-gradient(70% 60% at 50% 100%, color-mix(in srgb, var(--adw-mint) 42%, transparent) 0%, transparent 75%);
      }
    </style>
    """
  end

  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  @doc """
  Top bar on a hairline rule.

  The cart link sits outside any `sm:hidden` container — `theme_nav_audit_test`
  counts cart links that are reachable on desktop, and a theme whose only cart
  link lives in the mobile bar fails it.
  """
  def adwuma_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 border-b border-[color:var(--adw-rule)] bg-[color:var(--adw-bg)]/90 backdrop-blur [font-family:var(--adw-body)]">
      <div class="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
        <a
          href={store_path(@store.slug, "/")}
          class="text-lg font-semibold tracking-tight text-[color:var(--adw-ink)] [font-family:var(--adw-display)]"
        >
          {@store.name}
        </a>

        <nav class="hidden items-center gap-6 text-sm text-[color:var(--adw-muted)] sm:flex">
          <a href={store_path(@store.slug, "/products")} class="hover:text-[color:var(--adw-ink)]">
            Shop
          </a>
          <a
            :for={category <- Enum.take(@categories, 3)}
            href={store_path(@store.slug, "/category/#{category.slug}")}
            class="hover:text-[color:var(--adw-ink)]"
          >
            {category.name}
          </a>
          <a
            href={store_path(@store.slug, "/account/downloads")}
            class="hover:text-[color:var(--adw-ink)]"
          >
            Library
          </a>
        </nav>

        <a
          href={store_path(@store.slug, "/cart")}
          class="inline-flex items-center gap-2 rounded-full border border-[color:var(--adw-rule)] px-4 py-2 text-sm font-medium text-[color:var(--adw-ink)] hover:border-[color:var(--adw-ink)]"
        >
          Cart
          <span
            :if={@cart_count > 0}
            class="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-[color:var(--adw-ink)] px-1.5 text-xs font-semibold text-white"
          >
            {@cart_count}
          </span>
        </a>
      </div>
    </header>
    """
  end

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :show_add, :boolean, default: true

  def product_card(assigns) do
    assigns =
      assigns
      |> assign(:image, Cards.first_image(assigns.product))
      |> assign(:compare_at, Cards.compare_at_price(assigns.product))
      |> assign(:sold_out, Cards.sold_out?(assigns.product))

    ~H"""
    <div class="group [font-family:var(--adw-body)]">
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="relative block aspect-[4/3] overflow-hidden rounded-2xl border border-[color:var(--adw-rule)] bg-white"
      >
        <Cards.photo_or_initial image={@image} title={@product.title} />
        <span
          :if={@compare_at}
          class="absolute left-3 top-3 z-10 rounded-full bg-[color:var(--adw-lavender)] px-3 py-1 text-[0.6875rem] font-bold uppercase tracking-wide text-white"
        >
          Sale
        </span>
        <span
          :if={@sold_out}
          class="absolute left-3 top-3 z-10 rounded-full bg-[color:var(--adw-ink)]/90 px-3 py-1 text-[0.6875rem] font-bold uppercase tracking-wide text-white"
        >
          Sold out
        </span>
      </a>

      <div class="mt-3 flex items-start justify-between gap-3">
        <div class="min-w-0">
          <a href={store_path(@store.slug, "/products/#{@product.slug}")}>
            <h3 class="truncate text-base font-medium text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
              {@product.title}
            </h3>
          </a>
          <p class="mt-0.5 flex items-baseline gap-1.5 text-sm font-semibold tabular-nums text-[color:var(--adw-ink)]">
            {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
            <s :if={@compare_at} class="text-xs font-medium text-[color:var(--adw-muted)]">
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
          class="flex h-10 w-10 flex-shrink-0 cursor-pointer items-center justify-center rounded-full bg-[color:var(--adw-ink)] text-white hover:bg-[color:var(--adw-lavender)]"
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

  attr :store, :map, required: true
  attr :categories, :list, default: []

  @doc """
  Footer on the same pastel mesh as the hero, closed by a large translucent
  wordmark.

  The wordmark is `aria-hidden` and pointer-events-none — it is a graphic, and
  the store name is already announced in the nav. Footer is chrome rather than
  a section, so a merchant reordering their home page cannot remove it.
  """
  def footer(assigns) do
    ~H"""
    <footer class="relative mt-24 overflow-hidden border-t border-[color:var(--adw-rule)] [font-family:var(--adw-body)]">
      <div class="absolute inset-0 -z-10" style="background-image: var(--adw-mesh); opacity: 0.5">
      </div>

      <div class="mx-auto max-w-6xl px-4 py-16 sm:px-6">
        <div class="grid gap-10 sm:grid-cols-3">
          <div>
            <p class="text-base font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
              {@store.name}
            </p>
            <p class="mt-2 text-sm text-[color:var(--adw-muted)]">
              Pay with MTN MoMo, Telecel Cash, AirtelTigo Money or card.
            </p>
          </div>

          <div>
            <p class="text-xs font-semibold uppercase tracking-widest text-[color:var(--adw-muted)]">
              Shop
            </p>
            <ul class="mt-3 space-y-2 text-sm text-[color:var(--adw-ink)]">
              <li><a href={store_path(@store.slug, "/products")}>All items</a></li>
              <li :for={category <- Enum.take(@categories, 4)}>
                <a href={store_path(@store.slug, "/category/#{category.slug}")}>{category.name}</a>
              </li>
            </ul>
          </div>

          <div>
            <p class="text-xs font-semibold uppercase tracking-widest text-[color:var(--adw-muted)]">
              Your account
            </p>
            <ul class="mt-3 space-y-2 text-sm text-[color:var(--adw-ink)]">
              <li><a href={store_path(@store.slug, "/account/downloads")}>Downloads</a></li>
              <li><a href={store_path(@store.slug, "/account")}>Orders</a></li>
              <li><a href={store_path(@store.slug, "/contact")}>Contact</a></li>
            </ul>
          </div>
        </div>

        <p
          aria-hidden="true"
          class="pointer-events-none mt-12 select-none truncate text-[18vw] font-semibold leading-none tracking-tight text-[color:var(--adw-ink)]/[0.06] [font-family:var(--adw-display)]"
        >
          {@store.name}
        </p>
      </div>
    </footer>
    """
  end

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  @doc "Mobile bottom bar. The only `sm:hidden` nav in the theme."
  def bottom_nav(assigns) do
    ~H"""
    <nav class="fixed inset-x-0 bottom-0 z-40 border-t border-[color:var(--adw-rule)] bg-[color:var(--adw-bg)]/95 backdrop-blur sm:hidden [font-family:var(--adw-body)]">
      <div class="mx-auto flex max-w-md items-center justify-around px-2 py-2 text-xs text-[color:var(--adw-muted)]">
        <a href={store_path(@store.slug, "/")} class="px-3 py-1.5">Home</a>
        <a href={store_path(@store.slug, "/products")} class="px-3 py-1.5">Shop</a>
        <a href={store_path(@store.slug, "/account/downloads")} class="px-3 py-1.5">Library</a>
        <a
          href={store_path(@store.slug, "/cart")}
          class="px-3 py-1.5 font-semibold text-[color:var(--adw-ink)]"
        >
          Cart <span :if={@cart_count > 0}>({@cart_count})</span>
        </a>
      </div>
    </nav>
    """
  end
end
