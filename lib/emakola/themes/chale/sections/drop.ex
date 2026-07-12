defmodule Emakola.Themes.Chale.Sections.Drop do
  @moduledoc """
  Chale home drop — the newest active product presented as a release with
  a moment attached. This is real structure, not theatre: the product is
  genuinely the store's most recent, and the "New" stamp appears only when
  it went up within the last 14 days. No countdown to nothing.

  Renders nothing without products — the grid section owns the store's
  empty state, so a brand-new store never shows two of them.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Chale.Shared

  @impl true
  def key, do: "chale/drop"
  @impl true
  def label, do: "Latest drop"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "The latest drop"}]
  end

  @impl true
  def render(%{products: [product | _rest]} = assigns) do
    assigns =
      assigns
      |> assign(:product, product)
      |> assign(:heading, heading(assigns.settings))
      |> assign(:image, Shared.first_image(product))
      |> assign(:sold_out, Shared.sold_out?(product))

    ~H"""
    <section class="px-4 py-6 sm:px-6 sm:py-8 lg:px-8" aria-labelledby="chale-drop-heading">
      <div class="mx-auto max-w-[1280px]">
        <div class="mb-4 flex items-center gap-3">
          <h2
            id="chale-drop-heading"
            class="text-2xl font-bold uppercase tracking-tight text-[#101114] [font-family:var(--chale-display)] sm:text-3xl"
          >
            {@heading}
          </h2>
          <span
            :if={Shared.new_arrival?(@product)}
            class="-rotate-2 bg-store-accent px-2 py-1 text-[0.625rem] font-bold uppercase tracking-widest text-white"
          >
            New
          </span>
        </div>

        <div class="rounded-xl border border-[#E3E0DA] bg-white shadow-md md:grid md:grid-cols-2">
          <a
            href={store_path(@store.slug, "/products/#{@product.slug}")}
            class="relative block aspect-square focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2547E8] focus-visible:ring-inset md:border-r-2 md:border-[#E3E0DA]"
            aria-label={"View #{@product.title}"}
          >
            <div
              class="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-zinc-100 to-zinc-300"
              aria-hidden="true"
            >
              <span class="select-none text-9xl font-bold uppercase text-zinc-400 [font-family:var(--chale-display)]">
                {String.first(@product.title)}
              </span>
            </div>
            <.optimized_image
              :if={@image}
              src={@image}
              alt={@product.title}
              priority={:high}
              width={640}
              height={640}
              class="absolute inset-0 h-full w-full object-cover"
            />
            <div :if={@sold_out} class="absolute inset-0 z-[5] bg-white/60" aria-hidden="true"></div>
            <span
              :if={@sold_out}
              class="absolute right-4 top-4 z-10 -rotate-3 bg-[#101114] px-3 py-1.5 text-xs font-bold uppercase tracking-widest text-white"
            >
              Sold out
            </span>
            <div class="absolute bottom-4 left-4 z-10">
              <Shared.price_stamp product={@product} store={@store} size={:lg} />
            </div>
          </a>

          <div class="p-5 sm:p-6 md:flex md:flex-col md:justify-center md:p-8">
            <h3 class="mb-2 text-2xl font-bold uppercase leading-[0.95] tracking-tight text-[#101114] [font-family:var(--chale-display)] sm:text-3xl">
              <a
                href={store_path(@store.slug, "/products/#{@product.slug}")}
                class="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2547E8] focus-visible:ring-offset-2"
              >
                {@product.title}
              </a>
            </h3>
            <p
              :if={@product.description}
              class="mb-4 text-sm leading-relaxed text-zinc-600 line-clamp-3"
            >
              {@product.description}
            </p>
            <button
              :if={!@sold_out}
              type="button"
              phx-click="add_to_cart"
              phx-value-product-id={@product.id}
              class="mt-2 w-full cursor-pointer rounded-xl bg-store-accent px-6 py-4 text-sm font-bold uppercase tracking-widest text-white shadow-sm hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2547E8] focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:translate-y-0.5"
            >
              Add to cart
            </button>
            <button
              :if={@sold_out}
              type="button"
              disabled
              aria-disabled="true"
              class="mt-2 w-full cursor-not-allowed rounded-xl border border-[#E3E0DA] bg-zinc-200 px-6 py-4 text-sm font-bold uppercase tracking-widest text-zinc-500"
            >
              Sold out
            </button>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def render(assigns), do: ~H""

  defp heading(settings) do
    case settings["heading"] do
      value when is_binary(value) and value != "" -> value
      _ -> "The latest drop"
    end
  end
end
