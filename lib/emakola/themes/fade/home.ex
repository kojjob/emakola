defmodule Emakola.Themes.Fade.Home do
  @moduledoc """
  Fade theme home page — drop-driven streetwear, dark by default.

  Sections (gated by `@theme.sections.*` booleans):

    * **Hero** — full-bleed editorial drop shot or hard-edge dark canvas
    * **Drop counter** — "DROP 04 · DROPS IN 2D 14H 32M" with neon countdown
    * **Capsules** — 3-up dark tiles for capsule collections
    * **Featured piece** — single hero card with sold-out / X-left chip
    * **Drops grid** — drop_card grid with stock chips
    * **Lookbook** — full-bleed editorial film/photo strip
    * **Newsletter** — "Early access" subscribe block
    * **Footer** — minimal dark
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents,
    only: [
      optimized_image: 1,
      pattern_divider: 1
    ]

  alias Emakola.Themes.Fade.Shared
  alias EmakolaWeb.Helpers.Currency

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_product, fn -> List.first(assigns.products) end)
      |> assign_new(:capsule_categories, fn -> Enum.take(assigns.categories, 3) end)
      |> assign_new(:grid_products, fn -> assigns.products end)
      |> assign_new(:hero_title, fn -> hero_title(assigns) end)
      |> assign_new(:hero_subtitle, fn -> hero_subtitle(assigns) end)
      |> assign_new(:hero_image, fn -> hero_image(assigns) end)

    ~H"""
    <div class="min-h-screen bg-[#0A0A0A] text-[#FAFAFA]">
      <Shared.theme_styles theme={@theme} />

      <%!-- ── Hero ── --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden">
        <%= if @hero_image do %>
          <div class="relative aspect-[3/4] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[88vh]">
            <.optimized_image
              src={@hero_image}
              alt={"#{@store.name} — #{@hero_title}"}
              priority={:high}
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-[#0A0A0A] via-[#0A0A0A]/40 to-transparent">
            </div>
            <.hero_content title={@hero_title} subtitle={@hero_subtitle} store={@store} />
          </div>
        <% else %>
          <div class="relative bg-[#0A0A0A] border-b border-[#1F1F1F] py-24 sm:py-32 lg:py-40">
            <div class="absolute inset-0 opacity-[0.05]" aria-hidden="true">
              <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern
                    id="fade-grid"
                    x="0"
                    y="0"
                    width="40"
                    height="40"
                    patternUnits="userSpaceOnUse"
                  >
                    <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#FAFAFA" stroke-width="0.5" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#fade-grid)" />
              </svg>
            </div>
            <.hero_content title={@hero_title} subtitle={@hero_subtitle} store={@store} />
          </div>
        <% end %>
      </section>

      <%!-- ── Drop counter ── --%>
      <section
        :if={section_enabled?(@theme, :drop_counter)}
        class="bg-[#0A0A0A] border-y border-[#1F1F1F]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-5 flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-3">
            <span class="w-2 h-2 rounded-full bg-[var(--theme-accent,#00FF85)] animate-pulse"></span>
            <p
              class="text-[11px] font-semibold tracking-[0.25em] uppercase text-white"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              {@hero_title} · {@hero_subtitle}
            </p>
          </div>
          <div
            class="text-base sm:text-lg text-[var(--theme-accent,#00FF85)] tabular-nums tracking-wide"
            style="font-family: 'JetBrains Mono', monospace;"
          >
            02D : 14H : 32M : 11S
          </div>
        </div>
      </section>

      <%!-- ── Capsules ── --%>
      <section
        :if={section_enabled?(@theme, :capsules) and @capsule_categories != []}
        class="py-12 sm:py-16 bg-[#0A0A0A]"
        aria-labelledby="fade-capsules"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8 sm:mb-10 flex items-end justify-between">
            <h2
              id="fade-capsules"
              class="text-3xl sm:text-4xl text-white uppercase tracking-[0.04em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Capsules
            </h2>
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden sm:inline-flex text-[10px] font-semibold uppercase tracking-[0.25em] text-white hover:text-[var(--theme-accent,#00FF85)] transition-colors"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              All capsules →
            </a>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-1">
            <.capsule_tile
              :for={category <- @capsule_categories}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <.pattern_divider variant={:none} class="bg-[#0A0A0A]" />

      <%!-- ── Featured drop ── --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_product}
        class="py-12 sm:py-16 bg-[#0A0A0A]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.featured_drop product={@featured_product} store={@store} />
        </div>
      </section>

      <%!-- ── Drops grid ── --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-12 sm:py-16 bg-[#0A0A0A]"
        aria-labelledby="fade-drops"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8 sm:mb-10">
            <h2
              id="fade-drops"
              class="text-3xl sm:text-4xl text-white uppercase tracking-[0.04em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Live drops
            </h2>
          </div>
          <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 lg:grid-cols-4 lg:gap-5">
            <Shared.drop_card
              :for={product <- @grid_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- ── Lookbook strip ── --%>
      <section :if={section_enabled?(@theme, :lookbook)} class="py-12 sm:py-16 bg-[#0A0A0A]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8">
            <h2
              class="text-3xl sm:text-4xl text-white uppercase tracking-[0.04em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Lookbook
            </h2>
          </div>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-1">
            <.lookbook_panel
              :for={product <- Enum.take(@grid_products, 4)}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- ── Newsletter ── --%>
      <section
        :if={section_enabled?(@theme, :newsletter)}
        class="py-12 sm:py-16 bg-[#1F1F1F] border-y border-[#262626]"
      >
        <div class="max-w-xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[10px] font-bold tracking-[0.3em] uppercase text-[var(--theme-accent,#00FF85)] mb-3">
            24h before everyone else
          </p>
          <h2
            class="text-3xl sm:text-4xl text-white uppercase tracking-[0.04em] mb-3"
            style="font-family: 'Space Grotesk', sans-serif;"
          >
            Early access
          </h2>
          <p
            class="text-sm text-[#A3A3A3] mb-8"
            style="font-family: 'Inter', sans-serif;"
          >
            Subscribe and we'll send you next drops 24 hours before they go public.
          </p>
          <form
            class="flex flex-col sm:flex-row gap-2 max-w-md mx-auto"
            phx-submit="subscribe_newsletter"
          >
            <input
              type="email"
              name="email"
              placeholder="EMAIL"
              required
              class="flex-1 px-5 py-3 bg-[#0A0A0A] border border-[#262626] focus:outline-none focus:border-[var(--theme-accent,#00FF85)] text-sm text-white placeholder:text-[#525252] uppercase tracking-[0.15em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            />
            <button
              type="submit"
              class="px-8 py-3 bg-[var(--theme-accent,#00FF85)] text-[#0A0A0A] text-[11px] uppercase tracking-[0.25em] font-bold hover:bg-[#00CC6A] active:scale-[0.97] transition-all"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Get access
            </button>
          </form>
        </div>
      </section>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Hero Content ──

  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :store, :map, required: true

  defp hero_content(assigns) do
    ~H"""
    <div class="absolute inset-0 flex items-end sm:items-center">
      <div class="relative w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-20">
        <div class="max-w-3xl">
          <p
            class="text-[10px] font-bold tracking-[0.3em] uppercase text-[var(--theme-accent,#00FF85)] mb-4 sm:mb-6"
            style="font-family: 'Space Grotesk', sans-serif;"
          >
            {@subtitle}
          </p>
          <h1
            class="text-7xl sm:text-9xl lg:text-[10rem] text-white leading-[0.9] mb-8 uppercase tracking-[-0.02em]"
            style="font-family: 'Space Grotesk', sans-serif; font-weight: 700;"
          >
            {@title}
          </h1>
          <a
            href={"/s/#{@store.slug}/products"}
            class="inline-flex items-center gap-2 px-7 py-3 bg-[var(--theme-accent,#00FF85)] text-[#0A0A0A] text-[11px] font-bold uppercase tracking-[0.25em] hover:bg-[#00CC6A] active:scale-[0.97] transition-all"
            style="font-family: 'Space Grotesk', sans-serif;"
          >
            Shop the drop →
          </a>
        </div>
      </div>
    </div>
    """
  end

  # ── Capsule tile ──

  attr :category, :map, required: true
  attr :store_slug, :string, required: true

  defp capsule_tile(assigns) do
    ~H"""
    <a
      href={"/s/#{@store_slug}/category/#{@category.slug}"}
      class="group relative block aspect-[3/4] overflow-hidden bg-[#1F1F1F]"
    >
      <%= if Map.get(@category, :image_url) do %>
        <.optimized_image
          src={@category.image_url}
          alt={@category.name}
          class="w-full h-full object-cover opacity-80 group-hover:opacity-100 group-hover:scale-[1.03] transition-all duration-500"
        />
      <% else %>
        <div class="absolute inset-0 bg-gradient-to-br from-[#262626] to-[#0A0A0A]"></div>
      <% end %>
      <div class="absolute inset-0 bg-gradient-to-t from-[#0A0A0A]/80 to-transparent"></div>
      <div class="absolute inset-x-0 bottom-0 p-6 sm:p-8">
        <h3
          class="text-2xl sm:text-3xl text-white uppercase tracking-[0.02em] mb-2"
          style="font-family: 'Space Grotesk', sans-serif;"
        >
          {@category.name}
        </h3>
        <span
          class="inline-flex items-center gap-2 text-[10px] uppercase tracking-[0.25em] text-[var(--theme-accent,#00FF85)]"
          style="font-family: 'Space Grotesk', sans-serif;"
        >
          Enter →
        </span>
      </div>
    </a>
    """
  end

  # ── Featured drop ──

  defp featured_drop(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block group md:grid md:grid-cols-[60%_40%] items-stretch bg-[#1F1F1F] overflow-hidden"
      aria-label={"Featured: #{@product.title}"}
    >
      <div class="aspect-square md:aspect-auto md:h-full bg-[#0A0A0A] overflow-hidden relative">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-500"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-7xl text-[#404040]">checkroom</span>
        </div>
        <span
          class="absolute top-4 left-4 inline-flex items-center px-2.5 py-1 bg-[var(--theme-accent,#00FF85)] text-[#0A0A0A] text-[10px] font-bold uppercase tracking-[0.15em]"
          style="font-family: 'Space Grotesk', sans-serif;"
        >
          Featured drop
        </span>
      </div>
      <div class="p-6 sm:p-10 lg:p-12 flex flex-col justify-center">
        <h2
          class="text-3xl sm:text-4xl lg:text-5xl text-white uppercase tracking-[0.02em] mb-4 leading-[1.05]"
          style="font-family: 'Space Grotesk', sans-serif;"
        >
          {@product.title}
        </h2>
        <p
          :if={@product.description}
          class="text-sm sm:text-base text-[#A3A3A3] leading-relaxed mb-6 line-clamp-3"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p
          class="text-2xl text-[var(--theme-accent,#00FF85)] mb-6 tabular-nums"
          style="font-family: 'JetBrains Mono', monospace;"
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span
          class="inline-flex items-center justify-center gap-2 self-start px-7 py-3 bg-[#FAFAFA] text-[#0A0A0A] text-[11px] font-bold uppercase tracking-[0.25em] hover:bg-[var(--theme-accent,#00FF85)] transition-colors"
          style="font-family: 'Space Grotesk', sans-serif;"
        >
          Cop now →
        </span>
      </div>
    </a>
    """
  end

  # ── Lookbook panel ──

  attr :product, :map, required: true
  attr :store, :map, required: true

  defp lookbook_panel(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group block aspect-[3/4] bg-[#1F1F1F] overflow-hidden relative"
    >
      <.optimized_image
        :if={@image}
        src={@image}
        alt={@product.title}
        priority={:low}
        class="w-full h-full object-cover opacity-75 group-hover:opacity-100 transition-opacity duration-500"
      />
      <div :if={!@image} class="w-full h-full flex items-center justify-center">
        <span class="material-symbols-outlined text-5xl text-[#404040]">checkroom</span>
      </div>
      <div class="absolute inset-x-0 bottom-0 p-4 bg-gradient-to-t from-[#0A0A0A]/85 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
        <p
          class="text-xs text-white uppercase tracking-[0.15em] truncate"
          style="font-family: 'Space Grotesk', sans-serif;"
        >
          {@product.title}
        </p>
      </div>
    </a>
    """
  end

  # ── Helpers ──

  defp hero_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "DROP 04"
    end
  end

  defp hero_subtitle(assigns) do
    case get_in(assigns, [:theme, :hero, :subtitle]) do
      sub when is_binary(sub) and sub != "" -> sub
      _ -> "Limited run · Friday 18:00 GMT"
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
