defmodule Emakola.Themes.Luminous.Home do
  @moduledoc """
  Luminous theme home page — soft, aspirational, ingredient-honest.

  Sections (gated by `@theme.sections.*` booleans):

    * **Hero** — full-bleed soft-lit photography (model with products) or
      blush gradient fallback. Headline + subhead + dual CTA
      (Shop the routine + Take the quiz).
    * **Trust strip** — Clean ingredients / Dermatologist-tested / Made for African skin
    * **Browse by concern** — categories surfaced as concern-led tiles
      ("For oily skin / For glow / For sensitive") via occasion_collection_tile
    * **Featured product** — hero card with rose-gold accent + "Hero ingredient" callout
    * **Bundle deals** — 2-up promo cards inviting routine builds ("Save 15%")
    * **Product grid** — beauty_card grid with swatches and "Best for" badges
    * **Ingredient transparency strip** — 3-up callout (key ingredients)
    * **From our lab** — artisan_signature_card variant ("Meet the formulator")
    * **Newsletter** — quiz CTA ("Find your routine in 60 seconds")
    * **Footer** — beauty-brand pledge with payment methods
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

  alias Emakola.Themes.Luminous.Shared
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
    <div class="min-h-screen bg-[#FFFBF8]">
      <Shared.theme_styles theme={@theme} />

      <%!-- ── Hero — soft-lit beauty photography ── --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden">
        <%= if @hero_image do %>
          <div class="relative aspect-[4/5] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[78vh]">
            <.optimized_image
              src={@hero_image}
              alt={"#{@store.name} hero"}
              priority={:high}
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-r from-[#1F1717]/55 via-[#1F1717]/15 to-transparent">
            </div>
            <.hero_content store={@store} title={@hero_title} subtitle={@hero_subtitle} />
          </div>
        <% else %>
          <div class="relative bg-gradient-to-br from-[#FCE7F3] via-[#FBE4D9] to-[#F5E6D3] py-20 sm:py-28 lg:py-36">
            <div class="absolute inset-0 opacity-30" aria-hidden="true">
              <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern
                    id="luminous-pattern"
                    x="0"
                    y="0"
                    width="40"
                    height="40"
                    patternUnits="userSpaceOnUse"
                  >
                    <circle cx="20" cy="20" r="1.5" fill="#DB2777" fill-opacity="0.4" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#luminous-pattern)" />
              </svg>
            </div>
            <.hero_content
              store={@store}
              title={@hero_title}
              subtitle={@hero_subtitle}
              dark_text={true}
            />
          </div>
        <% end %>
      </section>

      <%!-- ── Trust Strip ── --%>
      <section
        :if={section_enabled?(@theme, :hero)}
        class="bg-white border-y border-[#FBCFE8]/40"
        aria-label="Why shop with us"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <.trust_badges_strip
            badges={[
              %{icon: "spa", label: "Clean ingredients", variant: :provenance},
              %{icon: "verified", label: "Dermatologist-tested", variant: :default},
              %{icon: "favorite", label: "Made for African skin", variant: :scarcity}
            ]}
            class="justify-center sm:justify-start"
          />
        </div>
      </section>

      <%!-- ── Browse by concern ── --%>
      <section
        :if={section_enabled?(@theme, :concerns) and @categories != []}
        class="py-12 sm:py-16 bg-[#FFFBF8]"
        aria-labelledby="luminous-concerns"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8 sm:mb-10 text-center">
            <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-primary,#DB2777)] mb-3">
              Personalised
            </p>
            <h2
              id="luminous-concerns"
              class="text-4xl sm:text-5xl text-[#1F1717] leading-tight"
              style="font-family: 'Cormorant Garamond', serif;"
            >
              Shop by concern
            </h2>
            <p
              class="mt-3 text-sm text-[#78716C] max-w-md mx-auto"
              style="font-family: 'Inter', sans-serif;"
            >
              Find products formulated for your skin type, weather, and routine.
            </p>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 sm:gap-6">
            <.occasion_collection_tile
              :for={category <- Enum.take(@categories, 6)}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <.pattern_divider variant={:none} class="bg-[#FFFBF8]" />

      <%!-- ── Featured product ── --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_product}
        class="py-10 sm:py-14 bg-[#FFFBF8]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.featured_product_card product={@featured_product} store={@store} />
        </div>
      </section>

      <%!-- ── Bundle deals ── --%>
      <section
        :if={section_enabled?(@theme, :bundles) and length(@bundle_products) >= 2}
        class="py-10 sm:py-14 bg-[#FFFBF8]"
        aria-labelledby="luminous-bundles"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-6 sm:mb-8 flex items-end justify-between">
            <div>
              <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-primary,#DB2777)] mb-2">
                Build the routine
              </p>
              <h2
                id="luminous-bundles"
                class="text-3xl sm:text-4xl text-[#1F1717]"
                style="font-family: 'Cormorant Garamond', serif;"
              >
                Bundles & duos
              </h2>
            </div>
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden sm:inline-flex text-sm font-medium text-[var(--theme-primary,#DB2777)] hover:text-[#9D174D] transition-colors items-center gap-1"
              style="font-family: 'Inter', sans-serif;"
            >
              All bundles
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
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
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-5 sm:gap-6">
            <.bundle_card
              product={Enum.at(@bundle_products, 0)}
              store={@store}
              accent="#FCE7F3"
              eyebrow="Glow Duo"
              save="Save 15%"
            />
            <.bundle_card
              product={Enum.at(@bundle_products, 1)}
              store={@store}
              accent="#F5E6D3"
              eyebrow="Daily Trio"
              save="Save 20%"
            />
          </div>
        </div>
      </section>

      <%!-- ── Product grid ── --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-10 sm:py-14 bg-[#FFFBF8]"
        aria-labelledby="luminous-shop-all"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-6 sm:mb-8">
            <div>
              <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-primary,#DB2777)] mb-2">
                The collection
              </p>
              <h2
                id="luminous-shop-all"
                class="text-3xl sm:text-4xl text-[#1F1717]"
                style="font-family: 'Cormorant Garamond', serif;"
              >
                Hand-picked for you
              </h2>
            </div>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm font-medium text-[var(--theme-primary,#DB2777)] hover:text-[#9D174D] transition-colors flex items-center gap-1"
              style="font-family: 'Inter', sans-serif;"
            >
              Shop all
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
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
            <Shared.beauty_card
              :for={product <- @grid_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- ── Ingredient transparency ── --%>
      <section
        :if={section_enabled?(@theme, :ingredients)}
        class="py-12 sm:py-16 bg-white border-y border-[#FBCFE8]/40"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8 sm:mb-10 text-center">
            <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-accent,#E5B299)] mb-3">
              Honest beauty
            </p>
            <h2
              class="text-3xl sm:text-4xl text-[#1F1717] leading-tight"
              style="font-family: 'Cormorant Garamond', serif;"
            >
              What we put in. What we leave out.
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6 sm:gap-8">
            <.ingredient_card
              icon="local_florist"
              title="Plant-derived actives"
              body="Shea, baobab, moringa — sourced from cooperatives across Ghana and the wider Sahel."
            />
            <.ingredient_card
              icon="science"
              title="Clinically tested"
              body="Each formula goes through dermatology testing before it reaches your shelf."
            />
            <.ingredient_card
              icon="block"
              title="Never the bad stuff"
              body="No parabens, no sulphates, no synthetic fragrance. Always cruelty-free."
            />
          </div>
        </div>
      </section>

      <%!-- ── Stories — artisan / formulator card ── --%>
      <section :if={section_enabled?(@theme, :stories)} class="py-10 sm:py-14 bg-[#FFFBF8]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.artisan_signature_card store={@store} headline="Meet the formulator" />
        </div>
      </section>

      <%!-- ── Newsletter / quiz CTA ── --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="py-10 sm:py-14">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-gradient-to-br from-[#FCE7F3] via-[#FBE4D9] to-[#F5E6D3] rounded-3xl p-8 sm:p-12 text-center border border-[#FBCFE8]/60">
            <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-primary,#DB2777)] mb-3">
              60-second quiz
            </p>
            <h2
              class="text-3xl sm:text-4xl text-[#1F1717] mb-3"
              style="font-family: 'Cormorant Garamond', serif;"
            >
              Find your routine
            </h2>
            <p
              class="text-[#78716C] text-base mb-6 max-w-md mx-auto"
              style="font-family: 'Inter', sans-serif;"
            >
              Answer a few questions about your skin and weather. Get a personalised routine,
              with monthly drops in your inbox.
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
                class="flex-1 px-5 py-3.5 rounded-full bg-white text-[#1F1717] placeholder:text-[#78716C]/60 border border-[#FBCFE8] focus:outline-none focus:ring-2 focus:ring-[var(--theme-primary,#DB2777)] focus:border-transparent text-sm"
                style="font-family: 'Inter', sans-serif;"
              />
              <button
                type="submit"
                class="px-8 py-3.5 bg-[var(--theme-primary,#DB2777)] text-white rounded-full text-sm font-semibold hover:bg-[#9D174D] active:scale-[0.97] transition-all shadow-md shadow-pink-300/40"
                style="font-family: 'Inter', sans-serif;"
              >
                Take the quiz
              </button>
            </form>
          </div>
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
  attr :dark_text, :boolean, default: false

  defp hero_content(assigns) do
    ~H"""
    <div class="absolute inset-0 flex items-end sm:items-center">
      <div class="relative w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-16">
        <div class="max-w-2xl">
          <span class={[
            "inline-flex items-center px-3 py-1.5 text-[10px] font-semibold tracking-[0.25em] uppercase rounded-full mb-4 backdrop-blur-sm border",
            if(@dark_text,
              do: "text-[#1F1717] bg-white/40 border-[#1F1717]/10",
              else: "text-white bg-white/15 border-white/20"
            )
          ]}>
            {@store.name}
          </span>
          <h1
            class={[
              "text-5xl sm:text-6xl lg:text-7xl leading-[1.05] mb-4 italic",
              if(@dark_text, do: "text-[#1F1717]", else: "text-white")
            ]}
            style="font-family: 'Cormorant Garamond', serif;"
          >
            {@title}
          </h1>
          <p
            class={[
              "text-base sm:text-lg leading-relaxed mb-7 max-w-lg",
              if(@dark_text, do: "text-[#1F1717]/80", else: "text-white/85")
            ]}
            style="font-family: 'Inter', sans-serif;"
          >
            {@subtitle}
          </p>
          <div class="flex flex-wrap gap-3">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "inline-flex items-center gap-2 px-7 py-3.5 rounded-full text-sm sm:text-base font-semibold active:scale-[0.97] transition-all shadow-md",
                if(@dark_text,
                  do:
                    "bg-[var(--theme-primary,#DB2777)] text-white hover:bg-[#9D174D] shadow-pink-300/40",
                  else: "bg-white text-[#1F1717] hover:bg-[#FCE7F3] shadow-black/20"
                )
              ]}
              style="font-family: 'Inter', sans-serif;"
            >
              Shop the routine
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
              href="#luminous-concerns"
              class={[
                "inline-flex items-center gap-2 px-6 py-3.5 rounded-full text-sm sm:text-base font-medium active:scale-[0.97] transition-all border",
                if(@dark_text,
                  do: "bg-white/40 text-[#1F1717] hover:bg-white/60 border-[#1F1717]/15",
                  else: "bg-white/10 text-white hover:bg-white/20 backdrop-blur-sm border-white/30"
                )
              ]}
              style="font-family: 'Inter', sans-serif;"
            >
              Take the quiz
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Featured product card ──

  defp featured_product_card(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block bg-white rounded-3xl overflow-hidden border border-[#FBCFE8]/40 hover:shadow-2xl hover:shadow-pink-200/40 transition-all duration-300 md:grid md:grid-cols-2"
      aria-label={"Featured product: #{@product.title}"}
    >
      <div class="w-full aspect-square md:aspect-auto md:h-full md:min-h-[420px] bg-[#FCE7F3]/30 overflow-hidden">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          class="w-full h-full object-cover"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-7xl text-[var(--theme-primary,#DB2777)]/50">
            spa
          </span>
        </div>
      </div>
      <div class="p-6 sm:p-10 md:p-12 md:flex md:flex-col md:justify-center">
        <span class="inline-flex items-center gap-1.5 px-3 py-1.5 text-[10px] font-semibold tracking-[0.25em] uppercase text-[#9D174D] bg-[#FCE7F3] rounded-full mb-4 w-fit">
          <span class="material-symbols-outlined text-[14px]">auto_awesome</span>
          Hero ingredient · Shea
        </span>
        <h2
          class="text-3xl sm:text-4xl text-[#1F1717] mb-3 leading-tight italic"
          style="font-family: 'Cormorant Garamond', serif;"
        >
          {@product.title}
        </h2>
        <p
          :if={@product.description}
          class="text-base text-[#57534E] leading-relaxed mb-5 line-clamp-3"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p class="text-2xl font-semibold text-[var(--theme-primary,#DB2777)] mb-6 tabular-nums">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span
          class="flex items-center justify-center gap-2 w-full py-4 px-6 bg-[#1F1717] text-white rounded-full text-sm font-semibold hover:bg-[#292524] active:scale-[0.97] transition-all shadow-lg shadow-stone-900/20 leading-none tracking-wide"
          style="font-family: 'Inter', sans-serif;"
        >
          Add to bag
          <svg
            class="w-4 h-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
            />
          </svg>
        </span>
      </div>
    </a>
    """
  end

  # ── Bundle card ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :accent, :string, required: true
  attr :eyebrow, :string, required: true
  attr :save, :string, required: true

  defp bundle_card(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group flex gap-5 rounded-3xl overflow-hidden p-5 sm:p-6 transition-all duration-300 hover:shadow-xl hover:shadow-pink-200/40 border border-[#FBCFE8]/40"
      style={"background-color: #{@accent};"}
      aria-label={"Bundle: #{@product.title}"}
    >
      <div class="flex-1 min-w-0 flex flex-col justify-center">
        <span class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[#9D174D] mb-2">
          {@eyebrow}
        </span>
        <h3
          class="text-2xl text-[#1F1717] leading-tight mb-2 italic"
          style="font-family: 'Cormorant Garamond', serif;"
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
        <div class="flex items-center gap-3 mb-3">
          <span class="text-base font-semibold text-[var(--theme-primary,#DB2777)] tabular-nums">
            {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
          </span>
          <span class="inline-flex items-center px-2.5 py-1 rounded-full bg-white/70 text-[10px] font-semibold text-[#9D174D] tracking-wide">
            {@save}
          </span>
        </div>
        <span
          class="inline-flex items-center gap-1 text-sm font-medium text-[#1F1717] group-hover:gap-2 transition-all"
          style="font-family: 'Inter', sans-serif;"
        >
          Build the routine
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
            />
          </svg>
        </span>
      </div>
      <div class="flex-shrink-0 w-32 sm:w-40 lg:w-48 aspect-square rounded-2xl overflow-hidden bg-white/60">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-4xl text-[var(--theme-primary,#DB2777)]/50">
            spa
          </span>
        </div>
      </div>
    </a>
    """
  end

  # ── Ingredient card ──

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true

  defp ingredient_card(assigns) do
    ~H"""
    <div class="text-center">
      <span class="inline-flex w-14 h-14 rounded-full bg-[#FCE7F3] items-center justify-center mb-4">
        <span class="material-symbols-outlined text-[28px] text-[var(--theme-primary,#DB2777)]">
          {@icon}
        </span>
      </span>
      <h3
        class="text-xl text-[#1F1717] mb-2"
        style="font-family: 'Cormorant Garamond', serif;"
      >
        {@title}
      </h3>
      <p
        class="text-sm text-[#57534E] leading-relaxed max-w-xs mx-auto"
        style="font-family: 'Inter', sans-serif;"
      >
        {@body}
      </p>
    </div>
    """
  end

  # ── Helpers ──

  defp hero_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "Made for your routine"
    end
  end

  defp hero_subtitle(assigns) do
    case get_in(assigns, [:theme, :hero, :subtitle]) do
      sub when is_binary(sub) and sub != "" ->
        sub

      _ ->
        case Map.get(assigns.store, :description) do
          desc when is_binary(desc) and desc != "" -> desc
          _ -> "Ingredient-honest beauty crafted for African skin and weather."
        end
    end
  end

  defp hero_image(assigns) do
    case get_in(assigns, [:theme, :hero, :image_url]) do
      url when is_binary(url) and url != "" -> url
      _ -> nil
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
