defmodule Emakola.Themes.Heirloom.Shared do
  @moduledoc """
  Heirloom chrome — CSS custom properties, nav and footer.

  The nav has two modes. Over the hero photograph it is transparent with
  light type (`on_dark`); everywhere else it sits on the page ground with
  ink type. Both are the same markup, so a link never moves between pages.

  Every `phx-` binding here names an event something actually handles:
  `subscribe_newsletter` is answered by
  `EmakolaWeb.Hooks.NewsletterSubscription` (attached on mount, params
  `%{"email" => ...}`). Storefront LiveViews have no catch-all
  `handle_event/3`, so an invented event name would crash the page rather
  than do nothing.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias EmakolaWeb.Helpers.CssColor

  @doc """
  Heirloom's custom properties.

  Merchant colour overrides pass through `safe_css_color/2`, which
  allowlists the value — these land inside a `<style>` block, so an
  unvalidated string would be a CSS injection.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --hl-ink: <%= CssColor.safe_css_color(get_in(@theme, [:colors, :text]), "#1B1208") %>;
        --hl-accent: <%= CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#E8983F") %>;
        --hl-bg: <%= CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#EFEFEF") %>;
        --hl-muted: <%= CssColor.safe_css_color(get_in(@theme, [:colors, :text_secondary]), "#8C8781") %>;
        --hl-border: <%= CssColor.safe_css_color(get_in(@theme, [:colors, :border]), "#DEDCD8") %>;
        --hl-tile: #E7E6E6;
        --hl-surface: #FFFFFF;
        --hl-deep: #000000;
        --hl-font: var(--dt-body-font, 'Outfit', system-ui, sans-serif);
        --hl-display: var(--dt-heading-font, 'Outfit', system-ui, sans-serif);
      }
    </style>
    """
  end

  @doc """
  The store's own name, used as the wordmark.

  Heirloom's footer sets this at display size, so it is the store's real
  identity rather than theme copy.
  """
  def wordmark(store), do: store.name || store.slug

  @doc """
  The variant whose price a card should show — the first one loaded.

  Returns `nil` for a product with no variants, and every caller renders
  no price rather than a zero.
  """
  def display_variant(product) do
    case Map.get(product, :variants) do
      [variant | _rest] -> variant
      _none -> nil
    end
  end

  @doc """
  A product's price, formatted in the store's currency, or `nil`.

  Amounts are integer minor units (pesewas); `format_price/2` is the only
  place they become a string.
  """
  def price_label(product, store) do
    case display_variant(product) do
      nil -> nil
      variant -> EmakolaWeb.Helpers.Currency.format_price(variant.price, store.currency)
    end
  end

  @doc """
  The struck-through was-price, when the variant genuinely carries one.

  `nil` unless `compare_at_price` is set AND higher than the price being
  charged — a theme must never manufacture a discount.
  """
  def compare_at_label(product, store) do
    with variant when not is_nil(variant) <- display_variant(product),
         compare when not is_nil(compare) <- Map.get(variant, :compare_at_price),
         true <- compare > variant.price do
      EmakolaWeb.Helpers.Currency.format_price(compare, store.currency)
    else
      _no_discount -> nil
    end
  end

  @doc """
  Nav links, resolved to routes that exist.

  Every href here was checked against the router. There is no `/categories`
  index — categories are reachable only as `/category/:slug` — so "Collections"
  points at the shop rather than at a 404 that would look fine in a render
  test.
  """
  def nav_links(store) do
    [
      {"Shop", store_path(store.slug, "/products")},
      {"Our story", store_path(store.slug, "/about")},
      {"Contact", store_path(store.slug, "/contact")}
    ]
  end

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :on_dark, :boolean, default: false
  attr :active_path, :string, default: ""

  def heirloom_nav(assigns) do
    ~H"""
    <header class={[
      "absolute inset-x-0 top-0 z-40",
      not @on_dark && "relative border-b border-[color:var(--hl-border)] bg-[color:var(--hl-bg)]"
    ]}>
      <nav
        aria-label="Primary"
        class="mx-auto flex max-w-[1360px] items-center gap-8 px-5 py-6 sm:px-8"
      >
        <a
          href={store_path(@store.slug, "/")}
          class={[
            "text-2xl tracking-tight [font-family:var(--hl-display)] font-light",
            @on_dark && "text-white",
            not @on_dark && "text-[color:var(--hl-ink)]"
          ]}
        >
          {wordmark(@store)}
        </a>

        <div class="hidden items-center gap-7 lg:flex">
          <a
            :for={{label, href} <- nav_links(@store)}
            href={href}
            class={[
              "text-[11px] font-medium uppercase tracking-[0.16em] motion-safe:transition-opacity hover:opacity-60",
              @on_dark && "text-white/90",
              not @on_dark && "text-[color:var(--hl-ink)]"
            ]}
          >
            {label}
          </a>
        </div>

        <div class="ml-auto flex items-center gap-5">
          <a
            href={store_path(@store.slug, "/cart")}
            class={[
              "text-[11px] font-medium uppercase tracking-[0.16em]",
              @on_dark && "text-white/90",
              not @on_dark && "text-[color:var(--hl-ink)]"
            ]}
          >
            Bag<span :if={@cart_count > 0}>&nbsp;({@cart_count})</span>
          </a>
          <a
            href={store_path(@store.slug, "/products")}
            class={[
              "hidden min-h-[44px] items-center rounded-full px-6 text-[11px] font-semibold uppercase tracking-[0.16em] sm:inline-flex",
              @on_dark && "bg-white text-[color:var(--hl-ink)]",
              not @on_dark && "bg-[color:var(--hl-ink)] text-white"
            ]}
          >
            Order now
          </a>
        </div>
      </nav>
    </header>
    """
  end

  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[color:var(--hl-deep)] text-white">
      <p
        aria-hidden="true"
        class="select-none overflow-hidden whitespace-nowrap px-2 pt-10 text-center font-light leading-[0.8] tracking-tight [font-family:var(--hl-display)] [font-size:clamp(4rem,19vw,18rem)]"
      >
        {wordmark(@store)}
      </p>

      <div class="mx-auto grid max-w-[1360px] gap-12 px-5 py-16 sm:px-8 lg:grid-cols-2">
        <div>
          <h2 class="text-2xl font-light [font-family:var(--hl-display)]">
            Subscribe to our newsletter
          </h2>
          <p class="mt-3 max-w-sm text-sm leading-relaxed text-white/60">
            New pieces, restocks and seasonal releases, straight to your inbox.
          </p>

          <form phx-submit="subscribe_newsletter" class="mt-6 flex max-w-sm items-center gap-2">
            <label for="heirloom-newsletter-email" class="sr-only">Email address</label>
            <div class="flex w-full items-center rounded-full bg-white/10 pr-1.5">
              <input
                id="heirloom-newsletter-email"
                type="email"
                name="email"
                required
                placeholder="Your email"
                class="min-h-[48px] w-full rounded-full border-0 bg-transparent px-6 text-sm text-white placeholder:text-white/40 focus:outline-none focus:ring-2 focus:ring-[color:var(--hl-accent)]"
              />
              <button
                type="submit"
                aria-label="Subscribe"
                class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white text-[color:var(--hl-ink)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)]"
              >
                &rarr;
              </button>
            </div>
          </form>
        </div>

        <div class="grid grid-cols-2 gap-8 sm:grid-cols-3">
          <div :if={@categories != []}>
            <p class="text-xs uppercase tracking-[0.16em] text-white/40">Shop</p>
            <ul class="mt-4 space-y-2.5">
              <li :for={category <- Enum.take(@categories, 4)}>
                <a
                  href={store_path(@store.slug, "/category/#{category.slug}")}
                  class="text-sm text-white/80 hover:text-white"
                >
                  {category.name}
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p class="text-xs uppercase tracking-[0.16em] text-white/40">Company</p>
            <ul class="mt-4 space-y-2.5">
              <li :for={
                {label, path} <- [
                  {"About", "/about"},
                  {"Contact", "/contact"},
                  {"Policies", "/policies"}
                ]
              }>
                <a
                  href={store_path(@store.slug, path)}
                  class="text-sm text-white/80 hover:text-white"
                >
                  {label}
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p class="text-xs uppercase tracking-[0.16em] text-white/40">Help</p>
            <%!-- No "Track order" link: tracking is /track/:order_number, so a
                 bare link would 404. A shopper reaches it from their order
                 confirmation, which carries the number. --%>
            <ul class="mt-4 space-y-2.5">
              <li :for={{label, path} <- [{"FAQ", "/faq"}, {"Contact", "/contact"}]}>
                <a
                  href={store_path(@store.slug, path)}
                  class="text-sm text-white/80 hover:text-white"
                >
                  {label}
                </a>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <div class="mx-auto max-w-[1360px] border-t border-white/10 px-5 py-6 sm:px-8">
        <p class="text-xs text-white/40">
          &copy; {Date.utc_today().year} {wordmark(@store)}. All rights reserved.
        </p>
      </div>
    </footer>
    """
  end
end
