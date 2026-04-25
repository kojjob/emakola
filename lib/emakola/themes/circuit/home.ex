defmodule Emakola.Themes.Circuit.Home do
  @moduledoc """
  Circuit theme home page — minimal tech retail.

  Sections (gated):
    * Hero — full-bleed device photography or dark canvas with crisp headline
    * Compare strip — "Side by side" link teasing the comparison page
    * Capsules — categories as dark glass tiles
    * Featured device — single hero card with key spec line
    * Devices grid — device_card grid with tech badges
    * Spec sheet teaser — "What we look for in a device"
    * Newsletter — stock alerts
    * Footer
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents,
    only: [
      optimized_image: 1,
      pattern_divider: 1
    ]

  alias Emakola.Themes.Circuit.Shared
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
    <div class="min-h-screen bg-[#0F0F12] text-white">
      <Shared.theme_styles theme={@theme} />

      <%!-- ── Hero ── --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden">
        <%= if @hero_image do %>
          <div class="relative aspect-[4/3] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[80vh]">
            <.optimized_image
              src={@hero_image}
              alt={"#{@store.name} — #{@hero_title}"}
              priority={:high}
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-[#0F0F12] via-[#0F0F12]/40 to-transparent">
            </div>
            <.hero_content title={@hero_title} subtitle={@hero_subtitle} store={@store} />
          </div>
        <% else %>
          <div class="relative bg-[#0F0F12] py-24 sm:py-32 lg:py-40 border-b border-[#27272A]">
            <div class="absolute inset-0 opacity-[0.04]" aria-hidden="true">
              <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern
                    id="circuit-grid"
                    x="0"
                    y="0"
                    width="60"
                    height="60"
                    patternUnits="userSpaceOnUse"
                  >
                    <circle cx="30" cy="30" r="1" fill="#FFFFFF" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#circuit-grid)" />
              </svg>
            </div>
            <.hero_content title={@hero_title} subtitle={@hero_subtitle} store={@store} />
          </div>
        <% end %>
      </section>

      <%!-- ── Compare strip ── --%>
      <section :if={section_enabled?(@theme, :compare)} class="bg-[#1A1A1F] border-y border-[#27272A]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-5 flex flex-wrap items-center justify-between gap-3">
          <p
            class="text-sm text-[#9CA3AF]"
            style="font-family: 'Inter', sans-serif;"
          >
            Trying to choose? Put two devices side by side.
          </p>
          <a
            href={"/s/#{@store.slug}/products"}
            class="inline-flex items-center gap-2 text-sm font-medium text-[var(--theme-accent,#3B82F6)] hover:text-white transition-colors"
            style="font-family: 'Inter', sans-serif;"
          >
            Compare devices →
          </a>
        </div>
      </section>

      <%!-- ── Capsules ── --%>
      <section
        :if={section_enabled?(@theme, :capsules) and @capsule_categories != []}
        class="py-16 sm:py-20 bg-[#0F0F12]"
        aria-labelledby="circuit-capsules"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2
            id="circuit-capsules"
            class="text-3xl sm:text-4xl font-semibold text-white mb-10 tracking-tight"
            style="font-family: 'Inter', sans-serif;"
          >
            Browse by category
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
            <.category_tile
              :for={category <- @capsule_categories}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <.pattern_divider variant={:none} class="bg-[#0F0F12]" />

      <%!-- ── Featured device ── --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_product}
        class="py-16 sm:py-24 bg-[#0F0F12]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.featured_device product={@featured_product} store={@store} />
        </div>
      </section>

      <%!-- ── Devices grid ── --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-16 sm:py-20 bg-[#0F0F12]"
        aria-labelledby="circuit-devices"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-10 flex items-end justify-between">
            <h2
              id="circuit-devices"
              class="text-3xl sm:text-4xl font-semibold text-white tracking-tight"
              style="font-family: 'Inter', sans-serif;"
            >
              In stock now
            </h2>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm font-medium text-[var(--theme-accent,#3B82F6)] hover:text-white transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              View all →
            </a>
          </div>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
            <Shared.device_card
              :for={product <- @grid_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- ── Spec philosophy ── --%>
      <section :if={section_enabled?(@theme, :specs)} class="py-16 sm:py-24 bg-[#1A1A1F]">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-accent,#3B82F6)] mb-4">
            What we look for
          </p>
          <h2
            class="text-3xl sm:text-4xl font-semibold text-white mb-8 tracking-tight"
            style="font-family: 'Inter', sans-serif;"
          >
            We only stock what we'd buy ourselves.
          </h2>
          <dl class="space-y-4">
            <.spec_row label="Authenticity" value="Sealed boxes, original packaging only." />
            <.spec_row label="Warranty" value="Manufacturer warranty on every unit." />
            <.spec_row label="Connectivity" value="5G, Wi-Fi 6, USB-C where available." />
            <.spec_row label="Returns" value="14-day return window, free pickup in Accra." />
          </dl>
        </div>
      </section>

      <%!-- ── Newsletter ── --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="py-16 sm:py-24 bg-[#0F0F12]">
        <div class="max-w-xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-accent,#3B82F6)] mb-3">
            First in line
          </p>
          <h2
            class="text-3xl sm:text-4xl font-semibold text-white mb-3 tracking-tight"
            style="font-family: 'Inter', sans-serif;"
          >
            Stock alerts
          </h2>
          <p
            class="text-sm text-[#9CA3AF] mb-8"
            style="font-family: 'Inter', sans-serif;"
          >
            Subscribe to be notified when new devices land or popular ones restock.
          </p>
          <form
            class="flex flex-col sm:flex-row gap-2 max-w-md mx-auto"
            phx-submit="subscribe_newsletter"
          >
            <input
              type="email"
              name="email"
              placeholder="you@example.com"
              required
              class="flex-1 px-5 py-3 bg-[#1A1A1F] border border-[#27272A] focus:outline-none focus:border-[var(--theme-accent,#3B82F6)] text-sm text-white placeholder:text-[#52525B] rounded-lg"
              style="font-family: 'Inter', sans-serif;"
            />
            <button
              type="submit"
              class="px-7 py-3 bg-[var(--theme-accent,#3B82F6)] text-white text-sm font-semibold hover:bg-[#2563EB] active:scale-[0.97] transition-all rounded-lg"
              style="font-family: 'Inter', sans-serif;"
            >
              Notify me
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
    <div class="absolute inset-0 flex items-center">
      <div class="relative w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-20 text-center">
        <h1
          class="text-5xl sm:text-7xl lg:text-8xl text-white leading-[1.05] mb-5 tracking-tight"
          style="font-family: 'Inter', sans-serif; font-weight: 700;"
        >
          {@title}
        </h1>
        <p
          class="text-base sm:text-lg lg:text-xl text-[#9CA3AF] max-w-xl mx-auto mb-8"
          style="font-family: 'Inter', sans-serif;"
        >
          {@subtitle}
        </p>
        <div class="flex flex-wrap gap-3 justify-center">
          <a
            href={"/s/#{@store.slug}/products"}
            class="inline-flex items-center gap-2 px-7 py-3 bg-white text-[#0F0F12] text-sm font-semibold rounded-full hover:bg-[#E5E7EB] active:scale-[0.97] transition-all"
            style="font-family: 'Inter', sans-serif;"
          >
            Shop devices
          </a>
          <a
            href={"/s/#{@store.slug}/products"}
            class="inline-flex items-center gap-2 px-6 py-3 text-sm font-medium text-white border border-white/20 rounded-full hover:border-white transition-all"
            style="font-family: 'Inter', sans-serif;"
          >
            Compare →
          </a>
        </div>
      </div>
    </div>
    """
  end

  # ── Category tile ──

  attr :category, :map, required: true
  attr :store_slug, :string, required: true

  defp category_tile(assigns) do
    ~H"""
    <a
      href={"/s/#{@store_slug}/category/#{@category.slug}"}
      class="group relative block aspect-[4/3] overflow-hidden bg-[#1A1A1F] rounded-2xl border border-[#27272A] hover:border-[var(--theme-accent,#3B82F6)] transition-colors"
    >
      <%= if Map.get(@category, :image_url) do %>
        <.optimized_image
          src={@category.image_url}
          alt={@category.name}
          class="w-full h-full object-cover opacity-70 group-hover:opacity-100 transition-opacity duration-300"
        />
      <% else %>
        <div class="absolute inset-0 bg-gradient-to-br from-[#27272A] to-[#1A1A1F]"></div>
      <% end %>
      <div class="absolute inset-x-0 bottom-0 p-6">
        <h3
          class="text-xl sm:text-2xl text-white font-semibold tracking-tight"
          style="font-family: 'Inter', sans-serif;"
        >
          {@category.name}
        </h3>
      </div>
    </a>
    """
  end

  # ── Featured device ──

  defp featured_device(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block group md:grid md:grid-cols-2 gap-8 lg:gap-16 items-center"
      aria-label={"Featured: #{@product.title}"}
    >
      <div class="aspect-square bg-[#1A1A1F] rounded-3xl overflow-hidden mb-6 md:mb-0">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-500"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-7xl text-[#3F3F46]">smartphone</span>
        </div>
      </div>
      <div>
        <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-accent,#3B82F6)] mb-4">
          Editor's pick
        </p>
        <h2
          class="text-4xl sm:text-5xl lg:text-6xl text-white font-semibold tracking-tight leading-[1.05] mb-5"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.title}
        </h2>
        <p
          :if={@product.description}
          class="text-base text-[#9CA3AF] leading-relaxed mb-8 max-w-md"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p
          class="text-2xl text-white mb-8 tabular-nums"
          style="font-family: 'JetBrains Mono', monospace;"
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span
          class="inline-flex items-center gap-2 px-7 py-3 bg-white text-[#0F0F12] text-sm font-semibold rounded-full"
          style="font-family: 'Inter', sans-serif;"
        >
          See specs →
        </span>
      </div>
    </a>
    """
  end

  # ── Spec row ──

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp spec_row(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-4 py-4 border-b border-[#27272A]">
      <dt
        class="text-sm font-medium text-[#9CA3AF] uppercase tracking-wide"
        style="font-family: 'Inter', sans-serif;"
      >
        {@label}
      </dt>
      <dd
        class="col-span-2 text-base text-white"
        style="font-family: 'Inter', sans-serif;"
      >
        {@value}
      </dd>
    </div>
    """
  end

  # ── Helpers ──

  defp hero_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "Tech, refined."
    end
  end

  defp hero_subtitle(assigns) do
    case get_in(assigns, [:theme, :hero, :subtitle]) do
      sub when is_binary(sub) and sub != "" -> sub
      _ -> "Curated electronics for the considered buyer. Sealed, warranted, supported."
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
