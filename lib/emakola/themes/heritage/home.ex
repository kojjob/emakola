defmodule Emakola.Themes.Heritage.Home do
  @moduledoc """
  Heritage theme home page — warm, story-driven, maker-forward.

  Sections (gated by `@theme.sections.*` booleans):

    * **Hero** — lifestyle shot of crafted item in a home setting, or warm
      gradient fallback. Two CTAs (Shop the workshop + Meet the makers).
    * **Maker spotlights** — 3-up cards above the fold, the maker is the hero
    * **Browse by room/use** — categories surfaced as room-context tiles
    * **Featured product in scene** — large card with room-context shot
    * **Product grid** — craft_card grid with "Handmade in [city]" badge
    * **Behind the craft** — story strip with thumbnails (linked reads)
    * **Gift bundles by occasion** — 2-up gift cards
    * **Newsletter** — "From the workshop" subscribe block
    * **Footer** — warm cream with maker pledge
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents,
    only: [
      optimized_image: 1,
      occasion_collection_tile: 1,
      artisan_signature_card: 1,
      pattern_divider: 1
    ]

  alias Emakola.Themes.Heritage.Shared
  alias EmakolaWeb.Helpers.Currency

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_product, fn -> List.first(assigns.products) end)
      |> assign_new(:bundle_products, fn -> Enum.take(assigns.products, 2) end)
      |> assign_new(:grid_products, fn -> assigns.products end)
      |> assign_new(:hero_title, fn -> hero_title(assigns) end)
      |> assign_new(:hero_subtitle, fn -> hero_subtitle(assigns) end)
      |> assign_new(:hero_image, fn -> hero_image(assigns) end)

    ~H"""
    <div class="min-h-screen bg-[#FFFBEB]">
      <Shared.theme_styles theme={@theme} />

      <%!-- ── Hero — lifestyle photography ── --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden">
        <%= if @hero_image do %>
          <div class="relative aspect-[4/5] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[80vh]">
            <.optimized_image
              src={@hero_image}
              alt={"#{@store.name} hero"}
              priority={:high}
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-r from-[#1C1917]/60 via-[#1C1917]/15 to-transparent">
            </div>
            <.hero_content store={@store} title={@hero_title} subtitle={@hero_subtitle} />
          </div>
        <% else %>
          <div class="relative bg-gradient-to-br from-[#A0522D] via-[#8B4513] to-[#5C2E0E] py-24 sm:py-32 lg:py-40">
            <div class="absolute inset-0 opacity-20" aria-hidden="true">
              <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern
                    id="heritage-pattern"
                    x="0"
                    y="0"
                    width="48"
                    height="48"
                    patternUnits="userSpaceOnUse"
                  >
                    <path
                      d="M0 24 L24 0 L48 24 L24 48 Z"
                      fill="none"
                      stroke="white"
                      stroke-width="0.5"
                      stroke-opacity="0.5"
                    />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#heritage-pattern)" />
              </svg>
            </div>
            <.hero_content store={@store} title={@hero_title} subtitle={@hero_subtitle} />
          </div>
        <% end %>
      </section>

      <%!-- ── Maker spotlights ── --%>
      <section
        :if={section_enabled?(@theme, :makers)}
        class="py-12 sm:py-16 bg-[#FFFBEB]"
        aria-labelledby="heritage-makers"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-10 text-center">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
              The hands behind the work
            </p>
            <h2
              id="heritage-makers"
              class="text-3xl sm:text-4xl text-[#1C1917]"
              style="font-family: 'Lora', serif;"
            >
              Meet the makers
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6">
            <.maker_spotlight
              name={@store.name}
              region={maker_location(@store)}
              technique="Master craftsperson"
              image_url={Map.get(@store, :logo_url)}
            />
            <.maker_spotlight
              name="Apprentice circle"
              region={Map.get(@store, :region) || "Ghana"}
              technique="In training, in good hands"
            />
            <.maker_spotlight
              name="Workshop guests"
              region="Visiting makers"
              technique="Limited residencies"
            />
          </div>
        </div>
      </section>

      <%!-- ── Browse by room / use ── --%>
      <section
        :if={section_enabled?(@theme, :rooms) and @categories != []}
        class="py-12 sm:py-16 bg-[#FFFBEB]"
        aria-labelledby="heritage-rooms"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8 sm:mb-10">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
              Find a place for it
            </p>
            <h2
              id="heritage-rooms"
              class="text-3xl sm:text-4xl text-[#1C1917]"
              style="font-family: 'Lora', serif;"
            >
              Browse by room
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
            <.occasion_collection_tile
              :for={category <- Enum.take(@categories, 6)}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <.pattern_divider variant={:ankara} class="bg-[#FFFBEB]" />

      <%!-- ── Featured product in scene ── --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_product}
        class="py-12 sm:py-16 bg-[#F4E4C1]/40"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.featured_in_scene product={@featured_product} store={@store} />
        </div>
      </section>

      <%!-- ── Product grid ── --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-12 sm:py-16 bg-[#FFFBEB]"
        aria-labelledby="heritage-shop-all"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8 sm:mb-10 flex items-end justify-between">
            <div>
              <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-2">
                The collection
              </p>
              <h2
                id="heritage-shop-all"
                class="text-3xl sm:text-4xl text-[#1C1917]"
                style="font-family: 'Lora', serif;"
              >
                From the workshop
              </h2>
            </div>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-xs sm:text-sm text-[var(--theme-primary,#A0522D)] hover:text-[#7C3F22] transition-colors flex items-center gap-1"
              style="font-family: 'Inter', sans-serif;"
            >
              See everything
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
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
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-6 lg:grid-cols-4 lg:gap-8">
            <Shared.craft_card
              :for={product <- @grid_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- ── Behind the craft (story strip) ── --%>
      <section
        :if={section_enabled?(@theme, :story)}
        class="py-12 sm:py-16 bg-white border-y border-[#E7DDC7]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8 sm:mb-10">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
              Read the journal
            </p>
            <h2
              class="text-3xl sm:text-4xl text-[#1C1917]"
              style="font-family: 'Lora', serif;"
            >
              Behind the craft
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6 sm:gap-8">
            <.story_card
              kicker="Field notes"
              title="A morning at the loom"
              body="The patterns we weave have been passed through six generations."
            />
            <.story_card
              kicker="Process"
              title="What 'kept for life' means"
              body="A short essay on materials, craftsmanship, and slow ownership."
            />
            <.story_card
              kicker="In the workshop"
              title="Tools we still make by hand"
              body="The chisels and looms our makers have built and rebuilt themselves."
            />
          </div>
        </div>
      </section>

      <%!-- ── Gift bundles ── --%>
      <section
        :if={section_enabled?(@theme, :bundles) and length(@bundle_products) >= 2}
        class="py-12 sm:py-16 bg-[#FFFBEB]"
        aria-labelledby="heritage-bundles"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8 sm:mb-10 text-center">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
              Considered gifts
            </p>
            <h2
              id="heritage-bundles"
              class="text-3xl sm:text-4xl text-[#1C1917]"
              style="font-family: 'Lora', serif;"
            >
              For the moments that matter
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-5 sm:gap-6">
            <.gift_bundle_card
              product={Enum.at(@bundle_products, 0)}
              store={@store}
              occasion="Naming ceremony"
            />
            <.gift_bundle_card
              product={Enum.at(@bundle_products, 1)}
              store={@store}
              occasion="Housewarming"
            />
          </div>
        </div>
      </section>

      <%!-- ── Maker signature ── --%>
      <section class="py-10 sm:py-14 bg-[#FFFBEB]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.artisan_signature_card store={@store} headline="A note from the workshop" />
        </div>
      </section>

      <%!-- ── Newsletter ── --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="py-12 sm:py-16">
        <div class="max-w-xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
            Quietly, occasionally
          </p>
          <h2
            class="text-3xl sm:text-4xl text-[#1C1917] mb-3"
            style="font-family: 'Lora', serif;"
          >
            From the workshop
          </h2>
          <p
            class="text-sm text-[#78716C] mb-8 leading-relaxed"
            style="font-family: 'Inter', sans-serif;"
          >
            Quiet updates on new makers, upcoming pieces, and the occasional behind-the-craft
            story. Two emails a month at most.
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
              class="flex-1 px-5 py-3 rounded-full border border-[#E7DDC7] bg-white focus:outline-none focus:border-[var(--theme-primary,#A0522D)] text-sm text-[#1C1917] placeholder:text-[#A8A29E]"
              style="font-family: 'Inter', sans-serif;"
            />
            <button
              type="submit"
              class="px-8 py-3 bg-[var(--theme-primary,#A0522D)] text-white rounded-full text-sm font-medium hover:bg-[#7C3F22] active:scale-[0.97] transition-all"
              style="font-family: 'Inter', sans-serif;"
            >
              Subscribe
            </button>
          </form>
        </div>
      </section>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Hero Content ──

  attr :store, :map, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true

  defp hero_content(assigns) do
    ~H"""
    <div class="absolute inset-0 flex items-end sm:items-center">
      <div class="relative w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-20">
        <div class="max-w-2xl">
          <p
            class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-highlight,#F4E4C1)] mb-4 sm:mb-6"
            style="font-family: 'Inter', sans-serif;"
          >
            {@store.name}
          </p>
          <h1
            class="text-4xl sm:text-5xl lg:text-6xl text-white leading-[1.05] mb-6"
            style="font-family: 'Lora', serif;"
          >
            {@title}
          </h1>
          <p
            class="text-base sm:text-lg text-white/90 leading-relaxed mb-8 max-w-lg"
            style="font-family: 'Inter', sans-serif;"
          >
            {@subtitle}
          </p>
          <div class="flex flex-wrap gap-3">
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center gap-2 px-7 py-3.5 bg-white text-[#1C1917] rounded-full text-sm sm:text-base font-medium hover:bg-[#FFFBEB] active:scale-[0.97] transition-all"
              style="font-family: 'Inter', sans-serif;"
            >
              Shop the workshop
              <svg
                class="w-4 h-4 sm:w-5 sm:h-5"
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
            <a
              href="#heritage-makers"
              class="inline-flex items-center gap-2 px-6 py-3.5 text-white border border-white/40 rounded-full text-sm sm:text-base font-medium hover:bg-white/10 transition-all"
              style="font-family: 'Inter', sans-serif;"
            >
              Meet the makers
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Maker spotlight ──

  attr :name, :string, required: true
  attr :region, :string, required: true
  attr :technique, :string, required: true
  attr :image_url, :string, default: nil

  defp maker_spotlight(assigns) do
    ~H"""
    <article class="bg-[#F4E4C1]/40 rounded-2xl overflow-hidden border border-[#E7DDC7]">
      <div class="aspect-[4/5] bg-[var(--theme-primary,#A0522D)]/10 overflow-hidden">
        <%= if @image_url do %>
          <.optimized_image
            src={@image_url}
            alt={"#{@name} portrait"}
            class="w-full h-full object-cover"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-[#A0522D] to-[#5C2E0E]">
            <span class="text-6xl text-white" style="font-family: 'Lora', serif;">
              {String.first(@name)}
            </span>
          </div>
        <% end %>
      </div>
      <div class="p-5 sm:p-6">
        <p class="text-[10px] tracking-[0.2em] uppercase text-[var(--theme-accent,#84A98C)] mb-2">
          {@region}
        </p>
        <h3
          class="text-xl text-[#1C1917] mb-1"
          style="font-family: 'Lora', serif;"
        >
          {@name}
        </h3>
        <p
          class="text-sm text-[#78716C]"
          style="font-family: 'Inter', sans-serif;"
        >
          {@technique}
        </p>
      </div>
    </article>
    """
  end

  # ── Featured in scene ──

  defp featured_in_scene(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block group md:grid md:grid-cols-[55%_45%] gap-8 lg:gap-12 items-center"
      aria-label={"Featured: #{@product.title}"}
    >
      <div class="aspect-[4/3] bg-white overflow-hidden rounded-2xl mb-6 md:mb-0">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-700"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-7xl text-[var(--theme-primary,#A0522D)]/40">
            chair
          </span>
        </div>
      </div>
      <div class="md:px-4 lg:px-8">
        <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
          The signature piece
        </p>
        <h2
          class="text-3xl sm:text-4xl lg:text-5xl text-[#1C1917] leading-[1.1] mb-5"
          style="font-family: 'Lora', serif;"
        >
          {@product.title}
        </h2>
        <p
          :if={@product.description}
          class="text-sm sm:text-base text-[#57534E] leading-relaxed mb-6 max-w-md"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p
          class="text-lg text-[var(--theme-primary,#A0522D)] mb-6 tabular-nums"
          style="font-family: 'Inter', sans-serif;"
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span
          class="inline-flex items-center gap-2 px-6 py-3 bg-[#1C1917] text-white rounded-full text-sm font-medium"
          style="font-family: 'Inter', sans-serif;"
        >
          See the piece →
        </span>
      </div>
    </a>
    """
  end

  # ── Story card ──

  attr :kicker, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true

  defp story_card(assigns) do
    ~H"""
    <article class="border-t border-[var(--theme-primary,#A0522D)] pt-5">
      <p class="text-[10px] tracking-[0.2em] uppercase text-[var(--theme-accent,#84A98C)] mb-2">
        {@kicker}
      </p>
      <h3
        class="text-xl sm:text-2xl text-[#1C1917] mb-2 leading-snug"
        style="font-family: 'Lora', serif;"
      >
        {@title}
      </h3>
      <p
        class="text-sm text-[#78716C] leading-relaxed"
        style="font-family: 'Inter', sans-serif;"
      >
        {@body}
      </p>
      <a
        href="#"
        class="mt-3 inline-flex items-center gap-1 text-xs uppercase tracking-[0.2em] text-[var(--theme-primary,#A0522D)] hover:text-[#7C3F22] transition-colors"
        style="font-family: 'Inter', sans-serif;"
      >
        Read on →
      </a>
    </article>
    """
  end

  # ── Gift bundle card ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :occasion, :string, required: true

  defp gift_bundle_card(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group flex gap-5 rounded-2xl overflow-hidden p-5 sm:p-6 transition-all duration-300 hover:bg-[#F4E4C1]/30 border border-[#E7DDC7]"
    >
      <div class="flex-1 min-w-0 flex flex-col justify-center">
        <p class="text-[10px] tracking-[0.2em] uppercase text-[var(--theme-accent,#84A98C)] mb-2">
          For {@occasion}
        </p>
        <h3
          class="text-xl sm:text-2xl text-[#1C1917] leading-tight mb-2"
          style="font-family: 'Lora', serif;"
        >
          {@product.title}
        </h3>
        <p
          :if={@product.description}
          class="text-sm text-[#78716C] leading-relaxed mb-3 line-clamp-2"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p
          class="text-base text-[var(--theme-primary,#A0522D)] tabular-nums"
          style="font-family: 'Inter', sans-serif;"
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
      </div>
      <div class="flex-shrink-0 w-32 sm:w-40 lg:w-48 aspect-square rounded-xl overflow-hidden bg-[#F4E4C1]/40">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-4xl text-[var(--theme-primary,#A0522D)]/50">
            redeem
          </span>
        </div>
      </div>
    </a>
    """
  end

  # ── Helpers ──

  defp hero_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "Hand-built in Bonwire"
    end
  end

  defp hero_subtitle(assigns) do
    case get_in(assigns, [:theme, :hero, :subtitle]) do
      sub when is_binary(sub) and sub != "" -> sub
      _ -> "Goods made by hand, kept for life. Each piece carries a maker's name."
    end
  end

  defp hero_image(assigns) do
    case get_in(assigns, [:theme, :hero, :image_url]) do
      url when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp maker_location(store) do
    [Map.get(store, :city), Map.get(store, :region)]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
    |> case do
      "" -> "West Africa"
      str -> str
    end
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
