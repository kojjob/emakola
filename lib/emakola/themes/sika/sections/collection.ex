defmodule Emakola.Themes.Sika.Sections.Collection do
  @moduledoc """
  Sika home vitrine — one piece at a time, given room.

  Deliberately NOT a thumbnail grid: each piece takes a full alternating
  row with a vitrine-framed image (velvet-tray placeholder first), the
  name in the display face, and the price stated plainly. No quick-add —
  a jewellery buyer views the piece before anything else.

  A store with zero pieces renders an intentional being-arranged state
  instead of nothing — a brand-new vitrine must never look broken.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Sika.Shared
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def key, do: "sika/collection"
  @impl true
  def label, do: "Collection"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: "The collection"},
      %{key: "limit", type: :integer, label: "Pieces shown", default: 6}
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:heading, Shared.present(assigns.settings["heading"]) || "The collection")
      |> assign(:pieces, Enum.take(assigns.products, limit(assigns.settings["limit"])))

    ~H"""
    <section
      :if={@pieces != []}
      class="px-4 py-10 sm:px-6 sm:py-14 lg:px-8"
      aria-labelledby="sika-collection-heading"
    >
      <div class="mx-auto max-w-[1200px]">
        <div class="text-center">
          <h2
            id="sika-collection-heading"
            class="text-2xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)] sm:text-3xl"
          >
            {@heading}
          </h2>
          <Shared.caught_light class="mx-auto mt-4 w-16" />
        </div>
        <div class="mt-12 space-y-16 sm:mt-16 sm:space-y-24">
          <article
            :for={{product, index} <- Enum.with_index(@pieces)}
            class="lg:grid lg:grid-cols-12 lg:items-center lg:gap-12"
          >
            <a
              href={store_path(@store.slug, "/products/#{product.slug}")}
              aria-label={"View #{product.title}"}
              class={[
                "group block border border-[#E8E3D9] bg-white p-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 sm:p-3 lg:col-span-7",
                rem(index, 2) == 1 && "lg:order-2"
              ]}
            >
              <div class="relative aspect-[4/5] overflow-hidden">
                <Shared.tray />
                <.optimized_image
                  :if={Shared.first_image(product)}
                  src={Shared.first_image(product)}
                  alt={product.title}
                  priority={if(index == 0, do: :high, else: :low)}
                  width={640}
                  height={800}
                  class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-700 motion-safe:group-hover:scale-[1.02]"
                />
                <span
                  :if={Shared.sold_out?(product)}
                  class="absolute right-2.5 top-2.5 inline-flex border border-white/20 bg-[#211D16]/85 px-2.5 py-1.5 text-[0.625rem] font-semibold uppercase tracking-[0.18em] text-white"
                >
                  Sold out
                </span>
              </div>
            </a>
            <div class={[
              "mt-6 lg:col-span-5 lg:mt-0",
              rem(index, 2) == 1 && "lg:order-1 lg:text-right"
            ]}>
              <h3 class="text-2xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)] sm:text-3xl">
                <a
                  href={store_path(@store.slug, "/products/#{product.slug}")}
                  class="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2"
                >
                  {product.title}
                </a>
              </h3>
              <p
                :if={product.description}
                class="mt-3 text-sm leading-relaxed text-[#6E675C] line-clamp-3"
              >
                {product.description}
              </p>
              <p class="mt-5 text-lg tabular-nums text-[#211D16]">
                {Currency.format_price_range(product.min_price, product.max_price, @store.currency)}
              </p>
              <a
                href={store_path(@store.slug, "/products/#{product.slug}")}
                class="mt-6 inline-flex items-center gap-2 border-b border-[#C2A15B]/60 pb-1 text-[0.75rem] font-semibold uppercase tracking-[0.2em] text-[#211D16] hover:border-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-colors"
              >
                View piece
                <svg
                  class="h-3.5 w-3.5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 4.5L21 12l-7.5 7.5M21 12H3"
                  />
                </svg>
              </a>
            </div>
          </article>
        </div>
      </div>
    </section>
    <section
      :if={@pieces == []}
      class="px-4 py-10 sm:px-6 sm:py-14 lg:px-8"
      aria-labelledby="sika-collection-empty-heading"
    >
      <div class="mx-auto max-w-[1200px] border border-[#E8E3D9] bg-white px-6 py-16 text-center sm:py-20">
        <span
          class="mx-auto flex h-16 w-16 items-center justify-center rounded-full border border-[#C2A15B]/50 text-2xl text-[#1F332C] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)] select-none"
          aria-hidden="true"
        >
          {String.first(@store.name)}
        </span>
        <h2
          id="sika-collection-empty-heading"
          class="mt-5 text-xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]"
        >
          The vitrine is being arranged
        </h2>
        <p class="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-[#6E675C]">
          {@store.name} hasn't added any pieces yet — return soon.
        </p>
      </div>
    </section>
    """
  end

  defp limit(value) when is_integer(value) and value > 0, do: value
  defp limit(_value), do: 6
end
