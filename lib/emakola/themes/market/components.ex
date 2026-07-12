defmodule Emakola.Themes.Market.Components do
  @moduledoc """
  Market theme "Stall" card components (spec:
  docs/superpowers/specs/2026-07-12-market-theme-elevation.md).

  Market-only — the shared `EmakolaWeb.StorefrontComponents` cards are used
  by eight other themes and must not be restyled. Three rules shape every
  component here:

    * Placeholder-first: the image slot is a warm stone panel carrying the
      product's initial and the price chip, so cards look finished before
      (or without) the photograph. The real image layers over it on arrival.
    * The price chip is the signature — tabular numerals in the merchant's
      heading font, notched corner, lower-left of the image.
    * The merchant's primary colour is the only accent: price chip,
      category ring hover (in the category strip section), primary CTA.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Market.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Image-free price tag: heading-family typography, tabular numerals, tight
  tracking, folded top-right corner. Renders instantly with zero image bytes.
  Carries the strikethrough compare-at ("was") price when the product is on
  sale — see `Shared.compare_at_price/1` for when that applies.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :size, :atom, values: [:sm, :lg], default: :sm

  def price_chip(assigns) do
    assigns = assign(assigns, :compare_at, Shared.compare_at_price(assigns.product))

    ~H"""
    <span class={[
      "inline-block bg-store-accent text-white font-bold tabular-nums tracking-tight",
      "[font-family:var(--dt-heading-font,inherit)]",
      "[clip-path:polygon(0_0,calc(100%_-_10px)_0,100%_10px,100%_100%,0_100%)]",
      if(@size == :lg,
        do: "text-2xl sm:text-3xl leading-none pl-3.5 pr-5 py-2.5",
        else: "text-[0.8125rem] leading-none pl-2.5 pr-3.5 py-1.5"
      )
    ]}>
      {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      <s :if={@compare_at} class="ml-0.5 text-[0.75em] font-medium text-white/70 line-through">
        <span class="sr-only">was</span>
        {Currency.format_price(@compare_at, @store.currency)}
      </s>
    </span>
    """
  end

  @doc """
  Grid product card: placeholder-first image slot with the price chip at the
  lower-left, title row with a quick add-to-cart button.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    assigns =
      assigns
      |> assign(:image, Shared.first_image(assigns.product))
      |> assign(:sold_out, Shared.sold_out?(assigns.product))

    ~H"""
    <div class="group">
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="block relative aspect-[3/4] rounded-2xl overflow-hidden border border-stone-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2"
      >
        <div
          class="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-stone-100 to-stone-200"
          aria-hidden="true"
        >
          <span class="text-6xl font-bold text-stone-400 [font-family:var(--dt-heading-font,inherit)] select-none">
            {String.first(@product.title)}
          </span>
        </div>
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          width={480}
          height={640}
          class="absolute inset-0 w-full h-full object-cover motion-safe:transition-transform motion-safe:duration-500 motion-safe:group-hover:scale-[1.03]"
        />
        <div :if={@sold_out} class="absolute inset-0 z-[5] bg-white/50" aria-hidden="true"></div>
        <span
          :if={@sold_out}
          class="absolute right-2.5 top-2.5 z-10 rounded-full bg-stone-900/90 px-2.5 py-1 text-[0.6875rem] font-bold uppercase tracking-wide text-white"
        >
          Sold out
        </span>
        <div class="absolute bottom-2.5 left-2.5 z-10">
          <.price_chip product={@product} store={@store} />
        </div>
      </a>
      <div class="mt-3 flex items-center justify-between gap-2">
        <a
          href={store_path(@store.slug, "/products/#{@product.slug}")}
          class="min-w-0 rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2"
        >
          <h3 class="text-sm font-semibold text-stone-900 leading-snug truncate">
            {@product.title}
          </h3>
        </a>
        <button
          :if={!@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="flex-shrink-0 flex items-center justify-center w-9 h-9 rounded-full bg-stone-900 text-white hover:bg-stone-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:scale-95 cursor-pointer"
          aria-label={"Add #{@product.title} to cart"}
        >
          <svg
            class="w-4 h-4"
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
          :if={@sold_out}
          type="button"
          disabled
          aria-disabled="true"
          class="flex-shrink-0 flex items-center justify-center w-9 h-9 rounded-full bg-stone-200 text-stone-400 cursor-not-allowed"
          aria-label={"#{@product.title} is sold out"}
        >
          <svg
            class="w-4 h-4"
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
  "Stall front" featured card: photo (placeholder-first) with an oversized
  price chip, name, and the page's primary CTA.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def featured_card(assigns) do
    assigns =
      assigns
      |> assign(:image, Shared.first_image(assigns.product))
      |> assign(:sold_out, Shared.sold_out?(assigns.product))

    ~H"""
    <div class="overflow-hidden rounded-[20px] border border-stone-200 bg-white md:grid md:grid-cols-2">
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="relative block aspect-[16/10] md:aspect-auto md:h-full md:min-h-[340px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-inset"
        aria-label={"View #{@product.title}"}
      >
        <div
          class="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-stone-100 to-stone-200"
          aria-hidden="true"
        >
          <span class="text-8xl font-bold text-stone-400 [font-family:var(--dt-heading-font,inherit)] select-none">
            {String.first(@product.title)}
          </span>
        </div>
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          width={640}
          height={400}
          class="absolute inset-0 w-full h-full object-cover"
        />
        <div :if={@sold_out} class="absolute inset-0 z-[5] bg-white/50" aria-hidden="true"></div>
        <span
          :if={@sold_out}
          class="absolute right-4 top-4 z-10 rounded-full bg-stone-900/90 px-3 py-1.5 text-xs font-bold uppercase tracking-wide text-white"
        >
          Sold out
        </span>
        <div class="absolute bottom-4 left-4 z-10">
          <.price_chip product={@product} store={@store} size={:lg} />
        </div>
      </a>
      <div class="p-5 sm:p-6 md:p-8 md:flex md:flex-col md:justify-center">
        <span class="block mb-2.5 text-[0.6875rem] font-bold uppercase tracking-[0.18em] text-stone-500">
          Featured
        </span>
        <h2 class="mb-1.5 text-xl sm:text-2xl font-bold leading-tight text-stone-900 [font-family:var(--dt-heading-font,inherit)]">
          <a
            href={store_path(@store.slug, "/products/#{@product.slug}")}
            class="rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2"
          >
            {@product.title}
          </a>
        </h2>
        <p :if={@product.description} class="mb-4 text-sm leading-relaxed text-stone-600 line-clamp-2">
          {@product.description}
        </p>
        <button
          :if={!@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="mt-2 flex w-full items-center justify-center rounded-full bg-store-accent px-6 py-3.5 text-[0.9375rem] font-semibold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98] cursor-pointer"
        >
          Add to Cart
        </button>
        <button
          :if={@sold_out}
          type="button"
          disabled
          aria-disabled="true"
          class="mt-2 flex w-full items-center justify-center rounded-full bg-stone-200 px-6 py-3.5 text-[0.9375rem] font-semibold leading-none text-stone-500 cursor-not-allowed"
        >
          Sold out
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Store story card: initial avatar, description (with a neutral fallback),
  and a WhatsApp CTA when the store has a number.
  """
  attr :store, :map, required: true

  def about_card(assigns) do
    ~H"""
    <section
      class="rounded-[20px] border border-stone-200 bg-white p-6 text-center sm:p-8"
      aria-labelledby="market-about-heading"
    >
      <div class="mx-auto mb-3.5 flex h-20 w-20 items-center justify-center rounded-full border border-stone-200 bg-gradient-to-br from-stone-100 to-stone-200">
        <span class="text-2xl font-bold text-stone-500 [font-family:var(--dt-heading-font,inherit)]">
          {String.first(@store.name)}
        </span>
      </div>
      <h2 id="market-about-heading" class="mb-2 text-lg font-bold tracking-tight text-stone-900">
        About the Shop
      </h2>
      <p class="mx-auto mb-4 max-w-[480px] text-sm leading-relaxed text-stone-600">
        {if @store.description,
          do: @store.description,
          else:
            "Welcome to #{@store.name}. Browse our collection of quality products handpicked for you."}
      </p>
      <a
        :if={Map.get(@store, :whatsapp_number)}
        href={"https://wa.me/#{@store.whatsapp_number}"}
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-2 rounded-full bg-whatsapp px-5 py-2.5 text-sm font-semibold text-white hover:bg-whatsapp-dark focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
      >
        <svg class="w-4.5 h-4.5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
          <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
        </svg>
        Chat on WhatsApp
      </a>
    </section>
    """
  end
end
