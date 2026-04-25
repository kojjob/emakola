defmodule Emakola.Themes.Savor.Home do
  @moduledoc """
  Savor theme home page — appetite-stimulating, communal, immediate.

  Sections (gated by `@theme.sections.*` booleans):

    * **Hero** — full-bleed plated food shot with steam/freshness language;
      conversational headline + delivery zone badge + dual CTA (Order now +
      WhatsApp call to order)
    * **Trust strip** — Made fresh today / Mobile money / WhatsApp orders
    * **Menu by meal type** — replaces generic occasion edits row; tiles for
      Breakfast / Lunch / Dinner / Drinks
    * **Featured dish** — large card with portion size + spice level + dual CTA
    * **Today's menu grid** — dish_card grid with stock-per-day chips on
      low-inventory items
    * **Delivery zone strip** — 3-up callout (zone name, ETA, fee)
    * **Customer favorites** — top reviews carousel (photo + name + rating)
    * **From our kitchen** — story spotlight (artisan_signature_card variant
      with `headline="From our kitchen"`)
    * **Newsletter** — "Today's menu in your inbox"
    * **Footer** — restaurant-style with hours, location, payment methods
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents,
    only: [
      optimized_image: 1,
      trust_badges_strip: 1,
      occasion_collection_tile: 1,
      artisan_signature_card: 1,
      pattern_divider: 1
    ]

  alias Emakola.Themes.Savor.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Savor theme home page.

  Expects assigns:
  - `@store` — store map (.name, .slug, .description, .whatsapp_number,
    optionally .city, .region, .logo_url, .contact_phone, .address)
  - `@products` — list of products (.title, .slug, .min_price, .max_price, .images)
  - `@categories` — list of root categories — used as meal-type tiles
  - `@theme` — theme config map (.sections booleans, optional .hero overrides)
  - `@delivery_zones` — optional list of delivery zones (.name, optional .eta, .fee)
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :delivery_zones, :list, default: []

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

      <%!-- ── Hero — full-bleed appetite shot ── --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden">
        <%= if @hero_image do %>
          <div class="relative aspect-[4/5] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[78vh]">
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
          <div class="relative bg-gradient-to-br from-[var(--theme-primary,#DC2626)] via-[#B91C1C] to-[#7C2D12] py-20 sm:py-24 lg:py-32">
            <div class="absolute inset-0 opacity-15" aria-hidden="true">
              <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern
                    id="savor-pattern"
                    x="0"
                    y="0"
                    width="32"
                    height="32"
                    patternUnits="userSpaceOnUse"
                  >
                    <circle cx="16" cy="16" r="2" fill="white" fill-opacity="0.6" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#savor-pattern)" />
              </svg>
            </div>
            <.hero_content store={@store} title={@hero_title} subtitle={@hero_subtitle} />
          </div>
        <% end %>
      </section>

      <%!-- ── Trust Strip ── --%>
      <section
        :if={section_enabled?(@theme, :hero)}
        class="bg-white border-y border-[#FDE68A]/60"
        aria-label="Why order with us"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <.trust_badges_strip
            badges={[
              %{icon: "local_fire_department", label: "Made fresh today", variant: :provenance},
              %{icon: "delivery_dining", label: "Same-day delivery", variant: :scarcity},
              %{icon: "payments", label: "MoMo · Vodafone · Cash", variant: :default}
            ]}
            class="justify-center sm:justify-start"
          />
        </div>
      </section>

      <%!-- ── Menu by meal type ── --%>
      <section
        :if={section_enabled?(@theme, :menu) and @categories != []}
        class="py-10 sm:py-14 bg-[#FFFBEB]"
        aria-labelledby="savor-menu"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-6 sm:mb-8">
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#DC2626)] mb-2">
              Today's menu
            </p>
            <h2
              id="savor-menu"
              class="text-3xl sm:text-4xl text-[#1C1917] tracking-wide"
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              WHAT'S COOKING
            </h2>
          </div>
          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-5 lg:gap-6">
            <.occasion_collection_tile
              :for={category <- Enum.take(@categories, 8)}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <.pattern_divider variant={:none} class="bg-[#FFFBEB]" />

      <%!-- ── Featured dish ── --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_product}
        class="py-8 sm:py-12 bg-[#FFFBEB]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.featured_dish_card product={@featured_product} store={@store} />
        </div>
      </section>

      <%!-- ── Today's menu grid ── --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-8 sm:py-12 bg-[#FFFBEB]"
        aria-labelledby="savor-todays-menu"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-6 sm:mb-8">
            <div>
              <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#DC2626)] mb-2">
                On the menu now
              </p>
              <h2
                id="savor-todays-menu"
                class="text-3xl sm:text-4xl text-[#1C1917] tracking-wide"
                style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
              >
                ORDER FRESH
              </h2>
            </div>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm font-semibold text-[var(--theme-primary,#DC2626)] hover:text-[#7C2D12] transition-colors flex items-center gap-1"
              style="font-family: 'Lora', serif;"
            >
              Full menu
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
            <Shared.dish_card :for={product <- @grid_products} product={product} store={@store} />
          </div>
        </div>
      </section>

      <%!-- ── Delivery zone strip ── --%>
      <section
        :if={section_enabled?(@theme, :delivery) and @delivery_zones != []}
        class="py-10 sm:py-14 bg-white border-y border-[#FDE68A]/60"
        aria-labelledby="savor-delivery"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-6">
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-accent,#15803D)] mb-2">
              We deliver to
            </p>
            <h2
              class="text-2xl sm:text-3xl text-[#1C1917] tracking-wide"
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              YOUR NEIGHBOURHOOD, FAST
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              :for={zone <- Enum.take(@delivery_zones, 6)}
              class="flex items-center gap-4 p-5 rounded-2xl bg-[#FFFBEB] border border-[#FDE68A]/60"
            >
              <span class="flex-shrink-0 w-12 h-12 rounded-full bg-[var(--theme-accent,#15803D)]/10 flex items-center justify-center">
                <span class="material-symbols-outlined text-[24px] text-[var(--theme-accent,#15803D)]">
                  delivery_dining
                </span>
              </span>
              <div class="min-w-0">
                <p
                  class="text-base font-bold text-[#1C1917] leading-tight"
                  style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
                >
                  {Map.get(zone, :name) || "Delivery zone"}
                </p>
                <p class="text-sm text-[#78350F]" style="font-family: 'Lora', serif;">
                  {delivery_summary(zone, @store)}
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- ── From our kitchen — artisan story ── --%>
      <section :if={section_enabled?(@theme, :story)} class="py-10 sm:py-14 bg-[#FFFBEB]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.artisan_signature_card store={@store} headline="From our kitchen" />
        </div>
      </section>

      <%!-- ── Newsletter ── --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="py-10 sm:py-14">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-gradient-to-br from-[#1C1917] to-[#292524] rounded-3xl p-8 sm:p-12 text-center">
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#DC2626)] mb-3">
              Tomorrow's menu
            </p>
            <h2
              class="text-3xl sm:text-4xl text-white mb-3 tracking-wide"
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              IN YOUR INBOX
            </h2>
            <p
              class="text-white/70 text-base mb-6 max-w-md mx-auto"
              style="font-family: 'Lora', serif;"
            >
              Be the first to know what's cooking and snag weekend specials before they sell out.
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
                class="flex-1 px-5 py-3.5 rounded-full bg-white/10 text-white placeholder:text-white/40 border border-white/20 focus:outline-none focus:ring-2 focus:ring-[var(--theme-primary,#DC2626)] focus:border-transparent text-sm"
                style="font-family: 'Lora', serif;"
              />
              <button
                type="submit"
                class="px-8 py-3.5 bg-[var(--theme-primary,#DC2626)] text-white rounded-full text-sm font-bold hover:bg-[#B91C1C] active:scale-[0.97] transition-all shadow-lg shadow-red-900/30 tracking-wide"
                style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
              >
                SUBSCRIBE
              </button>
            </form>
          </div>
        </div>
      </section>

      <Shared.footer store={@store} categories={@categories} />
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
          <span class="inline-flex items-center gap-1.5 px-3 py-1.5 text-[11px] font-bold tracking-[0.2em] uppercase text-white bg-white/15 rounded-full mb-4 backdrop-blur-sm border border-white/20">
            <span class="w-1.5 h-1.5 rounded-full bg-[#15803D] animate-pulse"></span>
            Cooking now · {@store.name}
          </span>
          <h1
            class="text-5xl sm:text-6xl lg:text-7xl text-white leading-[1.05] mb-4 tracking-wide"
            style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
          >
            {@title}
          </h1>
          <p
            class="text-base sm:text-lg text-white/85 leading-relaxed mb-7 max-w-lg"
            style="font-family: 'Lora', serif;"
          >
            {@subtitle}
          </p>
          <div class="flex flex-wrap gap-3">
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center gap-2 px-7 py-3.5 bg-white text-[#1C1917] rounded-full text-sm sm:text-base font-bold hover:bg-[#FEF3C7] active:scale-[0.97] transition-all shadow-lg shadow-black/20 tracking-wide"
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              ORDER NOW
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
              class="inline-flex items-center gap-2 px-6 py-3.5 bg-[#25D366] text-white rounded-full text-sm sm:text-base font-semibold hover:bg-[#1FB855] transition-all shadow-lg shadow-green-900/20"
              style="font-family: 'Lora', serif;"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347" />
              </svg>
              Order on WhatsApp
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Featured dish card ──

  defp featured_dish_card(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block bg-white rounded-3xl overflow-hidden border border-[#FDE68A]/60 hover:shadow-2xl hover:shadow-amber-200/40 transition-all duration-300 md:grid md:grid-cols-2"
      aria-label={"Featured dish: #{@product.title}"}
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
          <span class="material-symbols-outlined text-6xl text-[#D97706]">restaurant</span>
        </div>
      </div>
      <div class="p-6 sm:p-8 md:p-10 md:flex md:flex-col md:justify-center">
        <span class="inline-flex items-center px-3 py-1.5 text-[11px] font-bold tracking-[0.2em] uppercase text-white bg-[var(--theme-primary,#DC2626)] rounded-full mb-3 w-fit">
          Today's Special
        </span>
        <h2
          class="text-3xl sm:text-4xl text-[#1C1917] mb-2 leading-tight tracking-wide"
          style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
        >
          {String.upcase(@product.title)}
        </h2>
        <p
          :if={@product.description}
          class="text-base text-[#78350F] leading-relaxed mb-5 line-clamp-3"
          style="font-family: 'Lora', serif;"
        >
          {@product.description}
        </p>
        <p
          class="text-2xl text-[var(--theme-primary,#DC2626)] mb-5 tabular-nums"
          style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span
          class="flex items-center justify-center gap-2 w-full py-4 px-6 bg-[#1C1917] text-white rounded-full text-base font-bold hover:bg-[#292524] active:scale-[0.97] transition-all shadow-lg shadow-stone-900/20 leading-none tracking-wide"
          style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
        >
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
              d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007z"
            />
          </svg>
          ADD TO BAG
        </span>
      </div>
    </a>
    """
  end

  # ── Helpers ──

  defp hero_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "HOT FROM THE KITCHEN"
    end
  end

  defp hero_subtitle(assigns) do
    case get_in(assigns, [:theme, :hero, :subtitle]) do
      sub when is_binary(sub) and sub != "" ->
        sub

      _ ->
        case Map.get(assigns.store, :description) do
          desc when is_binary(desc) and desc != "" -> desc
          _ -> "Daily-cooked dishes ready to deliver across town. No preservatives, ever."
        end
    end
  end

  defp hero_image(assigns) do
    case get_in(assigns, [:theme, :hero, :image_url]) do
      url when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp delivery_summary(zone, store) do
    parts =
      [
        format_eta(Map.get(zone, :eta_minutes)),
        format_fee(Map.get(zone, :fee_amount), store)
      ]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))

    case parts do
      [] -> "Delivery available"
      _ -> Enum.join(parts, " · ")
    end
  end

  defp format_eta(minutes) when is_integer(minutes) and minutes > 0,
    do: "≈ #{minutes} min"

  defp format_eta(_), do: nil

  defp format_fee(nil, _store), do: nil
  defp format_fee(0, _store), do: "Free delivery"

  defp format_fee(amount, store) when is_integer(amount) do
    Currency.format_price(amount, store.currency)
  end

  defp format_fee(_, _), do: nil

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
