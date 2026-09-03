defmodule Emakola.Themes.Vibrant.Sections.Featured do
  @moduledoc """
  Vibrant featured product — the refined hero card for the shop's first product
  (`Emakola.Themes.Layout`), which the pair and the grid leave out so nothing
  is shown twice; a one-product shop is carried by this card alone.

  Carries the kente pattern divider that has always preceded it. The divider is
  deliberately outside the section's gate: on the pre-section home it rendered
  whether or not the featured card did, and dropping it for a store that turned
  the card off would change that store's page.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  import EmakolaWeb.StorefrontComponents,
    only: [optimized_image: 1, pattern_divider: 1]

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Vibrant.Shared
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def key, do: "vibrant/featured"

  @impl true
  def label, do: "Featured product"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    featured = Layout.of(assigns).featured

    assigns =
      assigns
      |> assign(:featured_product, featured)
      |> assign(
        :enabled,
        Shared.section_enabled?(assigns.theme, :featured) and not is_nil(featured)
      )

    ~H"""
    <.pattern_divider variant={:kente} class="bg-[#FFFBEB]" />

    <section :if={@enabled} class="py-8 sm:py-12 bg-[#FFFBEB]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <.featured_card product={@featured_product} store={@store} />
      </div>
    </section>
    """
  end

  # ── Featured Card ──

  attr :product, :map, required: true
  attr :store, :map, required: true

  defp featured_card(assigns) do
    assigns =
      assigns
      |> assign(:image, Shared.first_image(assigns.product))
      |> assign(:sold_out, Shared.sold_out?(assigns.product))

    ~H"""
    <div class="relative bg-white rounded-3xl overflow-hidden border border-[#FDE68A]/60 hover:shadow-2xl hover:shadow-amber-200/40 transition-all duration-300 md:grid md:grid-cols-2">
      <div class="w-full aspect-[16/10] md:aspect-auto md:h-full md:min-h-[380px] bg-[#FEF3C7]/30 overflow-hidden">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          class="w-full h-full object-cover"
        />
        <div
          :if={!@image}
          class="w-full h-full flex items-center justify-center"
          data-placeholder="product"
          aria-hidden="true"
        >
          <svg class="w-16 h-16 text-[#D97706]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        </div>
      </div>
      <div class="p-6 sm:p-8 md:p-10 md:flex md:flex-col md:justify-center">
        <span class="inline-flex items-center px-3 py-1.5 text-[11px] font-bold tracking-[0.2em] uppercase text-[var(--theme-primary,#B45309)] bg-[#FEF3C7] rounded-full mb-3 w-fit">
          Featured
        </span>
        <h2
          class="text-2xl sm:text-3xl font-bold text-[#1C1917] mb-2 leading-tight"
          style="font-family: 'Manrope', sans-serif;"
        >
          <%!-- Stretched link: the ::before covers the whole card, so the card
               stays clickable end to end while the bag button below stays a
               real button rather than an <a>-in-<a>. --%>
          <a
            href={store_path(@store.slug, "/products/#{@product.slug}")}
            class="before:absolute before:inset-0 before:rounded-3xl focus-visible:outline-none focus-visible:before:ring-2 focus-visible:before:ring-[#1C1917] focus-visible:before:ring-offset-2"
          >
            {@product.title}
          </a>
        </h2>
        <p
          :if={@product.description}
          class="text-base text-[#78350F] leading-relaxed mb-5 line-clamp-2"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p class="text-2xl font-bold text-[var(--theme-primary,#B45309)] mb-5 tabular-nums">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <button
          :if={!@sold_out}
          type="button"
          phx-click="add_to_cart"
          phx-value-product-id={@product.id}
          aria-label={"Add to bag: #{@product.title}"}
          class="relative flex items-center justify-center gap-2 w-full py-4 px-6 bg-[#1C1917] text-white rounded-full text-base font-bold cursor-pointer hover:bg-[#292524] active:scale-[0.97] transition-all shadow-lg shadow-stone-900/20 leading-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#1C1917] focus-visible:ring-offset-2"
        >
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
          Add to bag
        </button>
        <p
          :if={@sold_out}
          class="relative w-full py-4 px-6 bg-[#F5F5F4] text-[#78716C] rounded-full text-base font-bold text-center leading-none"
        >
          Sold out
        </p>
      </div>
    </div>
    """
  end
end
