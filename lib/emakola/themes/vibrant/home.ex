defmodule Emakola.Themes.Vibrant.Home do
  @moduledoc """
  Vibrant theme home page — bold, editorial, West African commerce-inspired.

  Sections (gated by `@theme.sections.*` booleans):

    * **Hero** — full-bleed merchant photo (or amber gradient fallback) with
      conversational headline, store description as subhead, dual CTA
      (Shop Now + WhatsApp).
    * **Trust badges strip** — provenance, mobile money, authenticated chips
      directly under the hero.
    * **Occasion edits** — top-level categories rendered as
      `occasion_collection_tile` cards in a responsive grid.
    * **Featured product** — refined hero card with amber palette.
    * **Product grid** — mobile-first 2/3/4-column responsive grid.
    * **Artisan signature** — `artisan_signature_card` surfaces the maker.
    * **Newsletter** — dark stone-900 callout with amber accent input.
    * **Footer** — delegated to Atelier.Shared.footer.

  Pattern dividers separate major sections to give visual rhythm.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  import EmakolaWeb.StorefrontComponents,
    only: [
      optimized_image: 1,
      trust_badges_strip: 1,
      occasion_collection_tile: 1,
      artisan_signature_card: 1,
      pattern_divider: 1
    ]

  alias Emakola.Themes.Vibrant.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Vibrant theme home page.

  Expects assigns:
  - `@store` — store map with `.name`, `.slug`, `.description`, `.whatsapp_number`,
    optionally `.city`, `.region`, `.logo_url`
  - `@products` — list of products with `.title`, `.slug`, `.min_price`, `.max_price`, `.images`
  - `@categories` — list of root categories with `.name`, `.slug`, optionally `.image_url`
  - `@theme` — theme config map with `.sections` booleans and optional `.hero` overrides
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_product, fn -> List.first(assigns.products) end)
      |> assign_new(:grid_products, fn -> assigns.products end)
      |> assign_new(:hero_title, fn -> hero_title(assigns) end)
      |> assign_new(:hero_subtitle, fn -> hero_subtitle(assigns) end)
      |> assign_new(:hero_image, fn -> hero_image(assigns) end)

    ~H"""
    <div class="min-h-screen bg-[#FFFBEB]">
      <Shared.theme_styles theme={@theme} />
      <Shared.vibrant_nav store={@store} cart_count={@cart_count} />

      <%!-- ── Editorial Hero ── --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden">
        <%= if @hero_image do %>
          <div class="relative aspect-[4/5] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[80vh]">
            <.optimized_image
              src={@hero_image}
              alt={"#{@store.name} hero"}
              priority={:high}
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-[#1C1917]/85 via-[#1C1917]/40 to-transparent">
            </div>
            <.hero_content store={@store} title={@hero_title} subtitle={@hero_subtitle} />
          </div>
        <% else %>
          <div class="relative bg-gradient-to-br from-[var(--theme-primary,#B45309)] via-[#D97706] to-[var(--theme-highlight,#F59E0B)] py-20 sm:py-24 lg:py-32">
            <div class="absolute inset-0 opacity-15" aria-hidden="true">
              <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern
                    id="vibrant-pattern"
                    x="0"
                    y="0"
                    width="40"
                    height="40"
                    patternUnits="userSpaceOnUse"
                  >
                    <circle cx="20" cy="20" r="6" fill="white" fill-opacity="0.4" />
                    <path
                      d="M0 20 L40 20 M20 0 L20 40"
                      stroke="white"
                      stroke-width="0.5"
                      stroke-opacity="0.3"
                    />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#vibrant-pattern)" />
              </svg>
            </div>
            <.hero_content store={@store} title={@hero_title} subtitle={@hero_subtitle} />
          </div>
        <% end %>
      </section>

      <%!-- ── Trust Badges Strip ── --%>
      <section
        :if={section_enabled?(@theme, :hero)}
        class="bg-white border-y border-[#FDE68A]/60"
        aria-label="Why shop with us"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <.trust_badges_strip
            badges={trust_badges_for(@store)}
            class="justify-center sm:justify-start"
          />
        </div>
      </section>

      <%!-- ── Editor's Picks (2-up flagship pair, inspired by Dynamite Foods Favorites) ── --%>
      <section
        :if={section_enabled?(@theme, :featured) and length(@products) >= 2}
        class="py-10 sm:py-14 bg-[#FFFBEB]"
        aria-labelledby="vibrant-editors-picks"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-6 sm:mb-8">
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#B45309)] mb-2">
              This Week
            </p>
            <h2
              id="vibrant-editors-picks"
              class="text-2xl sm:text-3xl font-bold text-[#1C1917]"
              style="font-family: 'Manrope', sans-serif;"
            >
              Editor's picks
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-5 sm:gap-6">
            <.editor_pick_card
              product={Enum.at(@products, 0)}
              store={@store}
              bg="#FEF3C7"
              text_color="#92400E"
            />
            <.editor_pick_card
              product={Enum.at(@products, 1)}
              store={@store}
              bg="#FEEFE0"
              text_color="#9A3412"
            />
          </div>
        </div>
      </section>

      <%!-- ── Occasion Edits ── --%>
      <section
        :if={section_enabled?(@theme, :categories) and @categories != []}
        class="py-10 sm:py-14 bg-[#FFFBEB]"
        aria-labelledby="vibrant-occasions"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-6 sm:mb-8">
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#B45309)] mb-2">
              Curated Edits
            </p>
            <h2
              id="vibrant-occasions"
              class="text-2xl sm:text-3xl font-bold text-[#1C1917]"
              style="font-family: 'Manrope', sans-serif;"
            >
              Shop the moments
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5 lg:gap-6">
            <.occasion_collection_tile
              :for={category <- Enum.take(@categories, 6)}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <.pattern_divider variant={:kente} class="bg-[#FFFBEB]" />

      <%!-- ── Featured Product ── --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_product}
        class="py-8 sm:py-12 bg-[#FFFBEB]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.featured_card product={@featured_product} store={@store} />
        </div>
      </section>

      <.pattern_divider variant={:ankara} class="bg-[#FFFBEB]" />

      <%!-- ── Product Grid ── --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-8 sm:py-12 bg-[#FFFBEB]"
        aria-labelledby="vibrant-shop-all"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-6 sm:mb-8">
            <div>
              <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#B45309)] mb-2">
                Just Landed
              </p>
              <h2
                id="vibrant-shop-all"
                class="text-2xl sm:text-3xl font-bold text-[#1C1917]"
                style="font-family: 'Manrope', sans-serif;"
              >
                Picked for you
              </h2>
            </div>
            <a
              href={store_path(@store.slug, "/products")}
              class="text-sm font-semibold text-[var(--theme-primary,#B45309)] hover:text-[var(--theme-accent,#7C2D12)] transition-colors flex items-center gap-1"
            >
              View all
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
          </div>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
            <Shared.product_card
              :for={product <- @grid_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <.pattern_divider variant={:kente} class="bg-[#FFFBEB]" />

      <%!-- ── Artisan Signature ── --%>
      <section :if={section_enabled?(@theme, :about)} class="py-10 sm:py-14 bg-[#FFFBEB]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.artisan_signature_card store={@store} headline="Meet the Maker" />
        </div>
      </section>

      <%!-- ── Newsletter ── --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="py-10 sm:py-14">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-gradient-to-br from-[#1C1917] to-[#292524] rounded-3xl p-8 sm:p-12 text-center">
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-highlight,#F59E0B)] mb-3">
              Stay in the loop
            </p>
            <h2
              class="text-2xl sm:text-3xl font-bold text-white mb-3"
              style="font-family: 'Manrope', sans-serif;"
            >
              First dibs on new arrivals
            </h2>
            <p
              class="text-white/70 text-base mb-6 max-w-md mx-auto"
              style="font-family: 'Inter', sans-serif;"
            >
              Get notified when fresh pieces drop and exclusive offers go live.
            </p>
            <form
              class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
              phx-submit="subscribe_newsletter"
            >
              <input
                type="email"
                name="email"
                placeholder="you@example.com"
                required
                class="flex-1 px-5 py-3.5 rounded-full bg-white/10 text-white placeholder:text-white/40 border border-white/20 focus:outline-none focus:ring-2 focus:ring-[var(--theme-highlight,#F59E0B)] focus:border-transparent text-sm"
                style="font-family: 'Inter', sans-serif;"
              />
              <button
                type="submit"
                class="px-8 py-3.5 bg-[var(--theme-primary,#B45309)] text-white rounded-full text-sm font-bold hover:bg-[#92400E] active:scale-[0.97] transition-all shadow-lg shadow-amber-900/30"
                style="font-family: 'Inter', sans-serif;"
              >
                Subscribe
              </button>
            </form>
          </div>
        </div>
      </section>

      <%!-- ── Service Strip (5-icon trust row, inspired by Cheranna footer service strip) ── --%>
      <section class="bg-white border-t border-[#E7E5E4]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4 sm:gap-6">
            <.service_pill
              icon="local_shipping"
              title="Free delivery"
              subtitle="Orders over GH₵200"
            />
            <.service_pill
              icon="account_balance_wallet"
              title="Mobile money"
              subtitle="MoMo, Vodafone, Card"
            />
            <.service_pill
              icon="chat"
              title="WhatsApp support"
              subtitle="Reply within an hour"
            />
            <.service_pill
              icon="verified"
              title="Authenticated"
              subtitle="Every item, every time"
            />
            <.service_pill
              icon="cached"
              title="Easy returns"
              subtitle="14-day window"
            />
          </div>
        </div>
      </section>

      <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Hero Content (shared between image and gradient variants) ──

  attr :store, :map, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true

  defp hero_content(assigns) do
    ~H"""
    <div class="absolute inset-0 flex items-end sm:items-center">
      <div class="relative w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-16">
        <div class="max-w-2xl">
          <span class="inline-flex items-center px-3 py-1.5 text-[11px] font-bold tracking-[0.2em] uppercase text-white bg-white/15 rounded-full mb-4 backdrop-blur-sm border border-white/20">
            {@store.name}
          </span>
          <h1
            class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-[1.05] mb-4"
            style="font-family: 'Manrope', sans-serif;"
          >
            {@title}
          </h1>
          <p
            class="text-base sm:text-lg text-white/85 leading-relaxed mb-7 max-w-lg"
            style="font-family: 'Inter', sans-serif;"
          >
            {@subtitle}
          </p>
          <div class="flex flex-wrap gap-3">
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center gap-2 px-7 py-3.5 bg-white text-[#1C1917] rounded-full text-sm sm:text-base font-bold hover:bg-[#FEF3C7] active:scale-[0.97] transition-all shadow-lg shadow-black/20"
              style="font-family: 'Inter', sans-serif;"
            >
              Shop the collection
              <svg
                class="w-4 h-4 sm:w-5 sm:h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
            <a
              :if={Map.get(@store, :whatsapp_number)}
              href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 px-6 py-3.5 bg-white/10 text-white rounded-full text-sm sm:text-base font-semibold hover:bg-white/20 backdrop-blur-sm transition-all border border-white/30"
              style="font-family: 'Inter', sans-serif;"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
              </svg>
              Chat with us
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Featured Card ──

  defp featured_card(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={store_path(@store.slug, "/products/#{@product.slug}")}
      class="block bg-white rounded-3xl overflow-hidden border border-[#FDE68A]/60 hover:shadow-2xl hover:shadow-amber-200/40 transition-all duration-300 md:grid md:grid-cols-2"
      aria-label={"Featured product: #{@product.title}"}
    >
      <div class="w-full aspect-[16/10] md:aspect-auto md:h-full md:min-h-[380px] bg-[#FEF3C7]/30 overflow-hidden">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          class="w-full h-full object-cover"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <svg
            class="w-16 h-16 text-[#D97706]"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
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
          {@product.title}
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
        <span class="flex items-center justify-center gap-2 w-full py-4 px-6 bg-[#1C1917] text-white rounded-full text-base font-bold hover:bg-[#292524] active:scale-[0.97] transition-all shadow-lg shadow-stone-900/20 leading-none">
          <svg
            class="w-5 h-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
          Add to bag
        </span>
      </div>
    </a>
    """
  end

  # ── Editor Pick Card (private) ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :bg, :string, required: true
  attr :text_color, :string, required: true

  defp editor_pick_card(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={store_path(@store.slug, "/products/#{@product.slug}")}
      class="group flex flex-col sm:flex-row gap-5 rounded-3xl overflow-hidden p-5 sm:p-6 transition-all duration-300 hover:shadow-xl hover:shadow-amber-200/40"
      style={"background-color: #{@bg};"}
      aria-label={"Editor's pick: #{@product.title}"}
    >
      <div class="flex-1 min-w-0 flex flex-col justify-center order-2 sm:order-1">
        <span
          class="text-[10px] font-bold tracking-[0.2em] uppercase mb-2"
          style={"color: #{@text_color};"}
        >
          Editor's Pick
        </span>
        <h3
          class="text-xl sm:text-2xl font-bold text-[#1C1917] leading-tight mb-2"
          style="font-family: 'Manrope', sans-serif;"
        >
          {@product.title}
        </h3>
        <p
          :if={@product.description}
          class="text-sm text-[#57534E] leading-relaxed mb-4 line-clamp-2"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p
          class="text-lg font-bold tabular-nums mb-4"
          style={"color: #{@text_color};"}
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span class="inline-flex items-center gap-1 text-sm font-semibold text-[#1C1917] group-hover:gap-2 transition-all">
          Shop now <span class="material-symbols-outlined text-base">arrow_forward</span>
        </span>
      </div>
      <div class="flex-shrink-0 w-full sm:w-40 lg:w-48 aspect-square rounded-2xl overflow-hidden bg-white/40 order-1 sm:order-2">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-4xl" style={"color: #{@text_color};"}>
            shopping_bag
          </span>
        </div>
      </div>
    </a>
    """
  end

  # ── Service Pill (private) ──

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true

  defp service_pill(assigns) do
    ~H"""
    <div class="flex items-start gap-3">
      <span class="flex-shrink-0 w-10 h-10 rounded-full bg-[#FEF3C7] flex items-center justify-center">
        <span class="material-symbols-outlined text-[20px] text-[var(--theme-primary,#B45309)]">
          {@icon}
        </span>
      </span>
      <div class="min-w-0">
        <p
          class="text-sm font-bold text-[#1C1917] leading-tight"
          style="font-family: 'Manrope', sans-serif;"
        >
          {@title}
        </p>
        <p class="text-xs text-[#78716C] mt-0.5 leading-snug">
          {@subtitle}
        </p>
      </div>
    </div>
    """
  end

  # ── Helpers ──

  defp hero_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "Discover #{assigns.store.name}"
    end
  end

  defp hero_subtitle(assigns) do
    cond do
      title = get_in(assigns, [:theme, :hero, :subtitle]) ->
        if title != "", do: title, else: store_subtitle(assigns)

      true ->
        store_subtitle(assigns)
    end
  end

  defp store_subtitle(%{store: %{description: desc}}) when is_binary(desc) and desc != "",
    do: desc

  defp store_subtitle(_),
    do: "Hand-picked pieces from our latest collection. Crafted with care, ready to ship."

  defp hero_image(assigns) do
    case get_in(assigns, [:theme, :hero, :image_url]) do
      url when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp trust_badges_for(_store) do
    [
      %{icon: "public", label: "Locally crafted", variant: :provenance},
      %{icon: "verified", label: "Authenticated", variant: :default},
      %{icon: "payments", label: "Mobile Money", variant: :default}
    ]
  end

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end

  defp section_enabled?(theme, section_name) do
    case theme do
      %{sections: sections} when is_map(sections) ->
        Map.get(sections, section_name, true)

      _ ->
        true
    end
  end
end
