defmodule Emakola.Themes.Pace.Components do
  @moduledoc """
  Pace's night-gradient card family. Pace-only — the shared
  `EmakolaWeb.StorefrontComponents` cards are used by other themes and
  must not be restyled.

  Three rules shape every card here:

    * Night-first: the image slot is a dark blue-black gradient carrying
      the product's ghost initial and a white price pill, so cards look
      finished before (or without) the photograph. The real image layers
      over it on arrival, then a bottom gradient wash guarantees the
      price stays legible over any photo.
    * Prices are white pills in the display face with tabular numerals —
      instantly legible on the night base, zero image bytes.
    * The merchant's primary colour is the accent, deployed sparingly:
      cart badge, add-to-cart hover, primary CTA.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Pace.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  White price pill: display-face typography, tabular numerals. Carries
  the strikethrough compare-at ("was") price when the product is on sale
  — see `Shared.compare_at_price/1` for when that applies.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :size, :atom, values: [:sm, :lg], default: :sm

  def price_pill(assigns) do
    assigns = assign(assigns, :compare_at, Shared.compare_at_price(assigns.product))

    ~H"""
    <span class={[
      "pace-display inline-block rounded-full bg-white font-bold tabular-nums text-slate-950",
      if(@size == :lg,
        do: "px-5 py-2.5 text-xl leading-none sm:text-2xl",
        else: "px-3 py-1.5 text-[0.8125rem] leading-none"
      )
    ]}>
      {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      <s :if={@compare_at} class="ml-0.5 text-[0.75em] font-medium text-slate-400 line-through">
        <span class="sr-only">was</span>
        {Currency.format_price(@compare_at, @store.currency)}
      </s>
    </span>
    """
  end

  @doc """
  Grid product card: night-gradient image slot with the ghost initial and
  the price pill at the lower-left, title row with a quick add-to-cart
  button below.
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
        class="relative block aspect-[3/4] overflow-hidden rounded-[20px] bg-gradient-to-b from-slate-800 to-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2"
      >
        <span
          class="pace-display absolute inset-0 flex select-none items-center justify-center text-7xl font-bold italic text-white/10"
          aria-hidden="true"
        >
          {String.first(@product.title)}
        </span>
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          width={480}
          height={640}
          class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-500 motion-safe:group-hover:scale-105"
        />
        <div
          class="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-slate-950/10 to-transparent"
          aria-hidden="true"
        >
        </div>
        <span
          :if={@sold_out}
          class="absolute right-2.5 top-2.5 z-10 rounded-full bg-white/90 px-2.5 py-1 text-[0.6875rem] font-bold uppercase tracking-wide text-slate-950"
        >
          Sold out
        </span>
        <div class="absolute bottom-2.5 left-2.5 z-10">
          <.price_pill product={@product} store={@store} />
        </div>
      </a>
      <div class="mt-3 flex items-center justify-between gap-2">
        <a
          href={store_path(@store.slug, "/products/#{@product.slug}")}
          class="min-w-0 rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2"
        >
          <h3 class="truncate text-sm font-semibold leading-snug text-slate-950">
            {@product.title}
          </h3>
        </a>
        <button
          :if={!@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="flex h-9 w-9 flex-shrink-0 cursor-pointer items-center justify-center rounded-full bg-slate-950 text-white hover:bg-store-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:scale-95"
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
          :if={@sold_out}
          type="button"
          disabled
          aria-disabled="true"
          class="flex h-9 w-9 flex-shrink-0 cursor-not-allowed items-center justify-center rounded-full bg-slate-200 text-slate-400"
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
  Front-runner featured card: a wide night slab with the photo (or ghost
  initial) washed by the dark gradient, oversized price pill, name, and
  the page's primary CTA.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def featured_card(assigns) do
    assigns =
      assigns
      |> assign(:image, Shared.first_image(assigns.product))
      |> assign(:sold_out, Shared.sold_out?(assigns.product))

    ~H"""
    <div class="overflow-hidden rounded-[24px] bg-gradient-to-br from-slate-800 via-slate-900 to-slate-950 text-white md:grid md:grid-cols-2">
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="relative block aspect-[16/10] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-white md:aspect-auto md:h-full md:min-h-[340px]"
        aria-label={"View #{@product.title}"}
      >
        <span
          class="pace-display absolute inset-0 flex select-none items-center justify-center text-9xl font-bold italic text-white/10"
          aria-hidden="true"
        >
          {String.first(@product.title)}
        </span>
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          width={640}
          height={400}
          class="absolute inset-0 h-full w-full object-cover"
        />
        <div
          class="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-slate-950/10 to-transparent"
          aria-hidden="true"
        >
        </div>
        <span
          :if={@sold_out}
          class="absolute right-4 top-4 z-10 rounded-full bg-white/90 px-3 py-1.5 text-xs font-bold uppercase tracking-wide text-slate-950"
        >
          Sold out
        </span>
        <div class="absolute bottom-4 left-4 z-10">
          <.price_pill product={@product} store={@store} size={:lg} />
        </div>
      </a>
      <div class="p-5 sm:p-6 md:flex md:flex-col md:justify-center md:p-8">
        <span class="mb-2.5 block text-[0.6875rem] font-bold uppercase tracking-[0.18em] text-slate-400">
          <span aria-hidden="true">///</span> Front runner
        </span>
        <h2 class="pace-display mb-1.5 text-2xl font-bold uppercase italic leading-tight tracking-tight sm:text-3xl">
          <a
            href={store_path(@store.slug, "/products/#{@product.slug}")}
            class="rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
          >
            {@product.title}
          </a>
        </h2>
        <p :if={@product.description} class="mb-4 text-sm leading-relaxed text-slate-300 line-clamp-2">
          {@product.description}
        </p>
        <button
          :if={!@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="mt-2 flex w-full cursor-pointer items-center justify-center rounded-full bg-store-accent px-6 py-3.5 text-[0.9375rem] font-semibold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-slate-950 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
        >
          Add to cart
        </button>
        <button
          :if={@sold_out}
          type="button"
          disabled
          aria-disabled="true"
          class="mt-2 flex w-full cursor-not-allowed items-center justify-center rounded-full bg-white/10 px-6 py-3.5 text-[0.9375rem] font-semibold leading-none text-slate-400"
        >
          Sold out
        </button>
      </div>
    </div>
    """
  end
end
