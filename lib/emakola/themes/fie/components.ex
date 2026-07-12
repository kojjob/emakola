defmodule Emakola.Themes.Fie.Components do
  @moduledoc """
  Fie's catalogue plates — the answer to the empty-white-page problem.

  On 2G the photos arrive late or never, and a white gallery without
  photos is a blank page. So every image slot here is a *composed plate*
  before a single image byte lands: a blush ground inside a hairline
  frame, the catalogue index number and price already set in Space
  Grotesk, and the piece's initial as the typographic ground. The
  pre-photo state reads as a printed catalogue page — deliberate, priced,
  scannable — never a grey skeleton. The photograph layers over the plate
  on arrival.

  The index numbers are real structure, not decoration: each plate is
  numbered by its position in the browse order, so the grid scans like
  the indexed catalogue it actually is.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Fie.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Zero-padded catalogue index — `4` becomes `"04"`.
  """
  def index_no(index) when is_integer(index) do
    index |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  @doc """
  Pluralised count label — `count_label(1, "piece")` is `"1 piece"`,
  `count_label(3, "piece")` is `"3 pieces"`.
  """
  def count_label(1, word), do: "1 #{word}"
  def count_label(n, word), do: "#{n} #{word}s"

  @doc """
  The catalogue's price line — plain ink, tabular numerals in the heading
  face, with the strikethrough compare-at ("was") price when the piece is
  on sale. Pure text: it renders instantly with zero image bytes.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def price_line(assigns) do
    assigns = assign(assigns, :compare_at, Shared.compare_at_price(assigns.product))

    ~H"""
    <span class="whitespace-nowrap text-xs font-medium tabular-nums tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif]">
      {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      <s :if={@compare_at} class="ml-0.5 font-normal text-stone-400 line-through">
        <span class="sr-only">was</span>
        {Currency.format_price(@compare_at, @store.currency)}
      </s>
    </span>
    """
  end

  @doc """
  A numbered catalogue plate: hairline top rule carrying the index and
  price, the blush image window (typographically composed before the
  photo arrives), then the title row with add-to-cart.

  `index` is the piece's real position in the browse order; pass nil to
  render an unnumbered plate (e.g. related pieces on the detail page).

  `add_to_cart` gates the quick-add button. It must be false on any page
  whose LiveView doesn't handle `add_to_cart` with a `product-id` payload:
  ProductListLive has no handler at all, and ProductDetailLive's handler
  adds the *current* product's variant regardless of payload — a quick-add
  on a related plate there would add the wrong piece.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :index, :integer, default: nil
  attr :add_to_cart, :boolean, default: true

  def catalogue_plate(assigns) do
    assigns =
      assigns
      |> assign(:image, Shared.first_image(assigns.product))
      |> assign(:sold_out, Shared.sold_out?(assigns.product))

    ~H"""
    <div class="group">
      <div class="mb-2.5 flex items-baseline justify-between gap-2 border-t border-[#EBDAD3] pt-2.5">
        <span
          :if={@index}
          class="text-xs font-medium tabular-nums text-stone-400 [font-family:'Space_Grotesk','Inter',sans-serif]"
        >
          {index_no(@index)}
        </span>
        <.price_line product={@product} store={@store} />
      </div>
      <a
        href={store_path(@store.slug, "/products/#{@product.slug}")}
        class="relative block aspect-[4/5] overflow-hidden border border-[#EBDAD3] bg-[#F7ECE7] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2"
      >
        <div class="absolute inset-0 flex items-center justify-center">
          <span
            class="select-none text-6xl font-medium text-[#D8BCB0] [font-family:'Space_Grotesk','Inter',sans-serif]"
            aria-hidden="true"
          >
            {String.first(@product.title)}
          </span>
        </div>
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          width={480}
          height={600}
          class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-500 motion-safe:group-hover:scale-[1.02]"
        />
        <div :if={@sold_out} class="absolute inset-0 z-[5] bg-white/60" aria-hidden="true"></div>
        <span
          :if={@sold_out}
          class="absolute right-2 top-2 z-10 bg-stone-900 px-2 py-1 text-[0.625rem] font-semibold uppercase tracking-[0.12em] text-white"
        >
          Sold out
        </span>
      </a>
      <div class="mt-2.5 flex items-center justify-between gap-2">
        <a
          href={store_path(@store.slug, "/products/#{@product.slug}")}
          class="min-w-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2"
        >
          <h3 class="truncate text-sm font-medium leading-snug text-stone-900">
            {@product.title}
          </h3>
        </a>
        <button
          :if={@add_to_cart && !@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          class="flex h-11 w-11 flex-shrink-0 cursor-pointer items-center justify-center border border-[#EBDAD3] text-stone-900 hover:bg-stone-900 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:scale-95"
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
          :if={@add_to_cart && @sold_out}
          type="button"
          disabled
          aria-disabled="true"
          class="flex h-11 w-11 flex-shrink-0 cursor-not-allowed items-center justify-center border border-[#EBDAD3] bg-[#F7ECE7] text-stone-400"
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
end
