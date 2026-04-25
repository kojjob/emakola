defmodule Emakola.Themes.Maison.Home do
  @moduledoc """
  Maison theme home page — restrained, photography-first, museum-grade.

  Sections (gated by `@theme.sections.*` booleans):

    * **Hero** — full-bleed editorial fashion shot with sparse overlay
      (collection name + season). No CTA buttons crowding the image —
      a single ghost link below the title.
    * **Lookbook intro** — short editorial passage about the season
    * **Capsule collections** — 3-up large tiles with portrait photography
      and minimal hover interaction
    * **Featured product** — single hero card with sparse copy
    * **Product grid** — tall portrait_card grid (2/3/4-col)
    * **Designer's note** — single-column serif testimonial from the maker
    * **Newsletter** — "Private list" subscribe block
    * **Footer** — editorial: stockists / press / contact
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents,
    only: [
      optimized_image: 1,
      pattern_divider: 1
    ]

  alias Emakola.Themes.Maison.Shared
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
    <div class="min-h-screen bg-white">
      <Shared.theme_styles theme={@theme} />

      <%!-- ── Hero — sparse editorial overlay ── --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden">
        <%= if @hero_image do %>
          <div class="relative aspect-[3/4] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[88vh]">
            <.optimized_image
              src={@hero_image}
              alt={"#{@store.name} — #{@hero_title}"}
              priority={:high}
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-[#1C1917]/60 via-transparent to-transparent">
            </div>
            <.hero_content title={@hero_title} subtitle={@hero_subtitle} store={@store} />
          </div>
        <% else %>
          <div class="relative bg-[#1C1917] py-28 sm:py-36 lg:py-44">
            <.hero_content title={@hero_title} subtitle={@hero_subtitle} store={@store} />
          </div>
        <% end %>
      </section>

      <%!-- ── Lookbook intro ── --%>
      <section
        :if={section_enabled?(@theme, :lookbook)}
        class="py-16 sm:py-24 bg-white"
        aria-labelledby="maison-lookbook"
      >
        <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-4">
            The Edit
          </p>
          <h2
            id="maison-lookbook"
            class="text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-[1.1] mb-6"
            style="font-family: 'Playfair Display', serif;"
          >
            A study in restraint
          </h2>
          <p
            class="text-base sm:text-lg text-[#78716C] leading-relaxed font-light"
            style="font-family: 'Inter', sans-serif;"
          >
            {lookbook_intro(@store)}
          </p>
        </div>
      </section>

      <%!-- ── Capsule collections ── --%>
      <section
        :if={section_enabled?(@theme, :capsules) and @capsule_categories != []}
        class="py-12 sm:py-16 bg-white"
        aria-labelledby="maison-capsules"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-10 sm:mb-14 flex items-end justify-between">
            <h2
              id="maison-capsules"
              class="text-3xl sm:text-4xl text-[#1C1917]"
              style="font-family: 'Playfair Display', serif;"
            >
              Capsule collections
            </h2>
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden sm:inline-flex text-[10px] uppercase tracking-[0.25em] text-[#1C1917] hover:text-[var(--theme-accent,#D4A843)] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              All collections →
            </a>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-1 sm:gap-2">
            <.capsule_tile
              :for={category <- @capsule_categories}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <.pattern_divider variant={:none} class="bg-white" />

      <%!-- ── Featured piece ── --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_product}
        class="py-12 sm:py-20 bg-[#F5F5F4]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.featured_piece product={@featured_product} store={@store} />
        </div>
      </section>

      <%!-- ── Product grid ── --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-16 sm:py-24 bg-white"
        aria-labelledby="maison-shop-all"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-10 sm:mb-12 text-center">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-3">
              The collection
            </p>
            <h2
              id="maison-shop-all"
              class="text-3xl sm:text-4xl lg:text-5xl text-[#1C1917]"
              style="font-family: 'Playfair Display', serif;"
            >
              Newly arrived
            </h2>
          </div>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-8 lg:grid-cols-4 lg:gap-10">
            <Shared.portrait_card
              :for={product <- @grid_products}
              product={product}
              store={@store}
            />
          </div>
          <div class="mt-12 text-center">
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center gap-2 px-8 py-3 border border-[#1C1917] text-[#1C1917] text-[11px] uppercase tracking-[0.25em] hover:bg-[#1C1917] hover:text-white transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              View all
            </a>
          </div>
        </div>
      </section>

      <%!-- ── Designer's note ── --%>
      <section
        :if={section_enabled?(@theme, :designer_note)}
        class="py-16 sm:py-24 bg-[#F5F5F4]"
      >
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-6">
            Designer's note
          </p>
          <%= if Map.get(@store, :logo_url) do %>
            <.optimized_image
              src={@store.logo_url}
              alt={"#{@store.name} portrait"}
              priority={:low}
              class="w-20 h-20 sm:w-24 sm:h-24 rounded-full object-cover mx-auto mb-6 ring-1 ring-[#E7E5E4]"
            />
          <% end %>
          <p
            class="text-2xl sm:text-3xl lg:text-4xl text-[#1C1917] italic leading-snug mb-6"
            style="font-family: 'Playfair Display', serif;"
          >
            "{designer_quote(@store)}"
          </p>
          <p
            class="text-sm tracking-[0.15em] uppercase text-[#78716C]"
            style="font-family: 'Inter', sans-serif;"
          >
            — {@store.name}
            <span :if={designer_location(@store) != ""}>
              · {designer_location(@store)}
            </span>
          </p>
        </div>
      </section>

      <%!-- ── Newsletter ── --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="py-16 sm:py-24 bg-white">
        <div class="max-w-xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-3">
            By invitation
          </p>
          <h2
            class="text-3xl sm:text-4xl text-[#1C1917] mb-3"
            style="font-family: 'Playfair Display', serif;"
          >
            The private list
          </h2>
          <p
            class="text-sm text-[#78716C] mb-8 font-light leading-relaxed"
            style="font-family: 'Inter', sans-serif;"
          >
            New collections, in-person trunk shows, and archive drops — sent only to subscribers.
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
              class="flex-1 px-5 py-3 border border-[#E7E5E4] focus:outline-none focus:border-[#1C1917] text-sm text-[#1C1917] placeholder:text-[#A8A29E]"
              style="font-family: 'Inter', sans-serif;"
            />
            <button
              type="submit"
              class="px-8 py-3 bg-[#1C1917] text-white text-[11px] uppercase tracking-[0.25em] hover:bg-[#292524] active:scale-[0.97] transition-all"
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

  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :store, :map, required: true

  defp hero_content(assigns) do
    ~H"""
    <div class="absolute inset-0 flex items-end sm:items-center">
      <div class="relative w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-20">
        <div class="max-w-2xl">
          <p
            class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-4 sm:mb-6"
            style="font-family: 'Inter', sans-serif;"
          >
            {@subtitle}
          </p>
          <h1
            class="text-5xl sm:text-7xl lg:text-8xl text-white leading-[0.95] mb-8 italic"
            style="font-family: 'Playfair Display', serif;"
          >
            {@title}
          </h1>
          <a
            href={"/s/#{@store.slug}/products"}
            class="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.25em] text-white border-b border-white/40 pb-1 hover:border-white transition-colors"
            style="font-family: 'Inter', sans-serif;"
          >
            View collection →
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
      class="group relative block aspect-[3/4] overflow-hidden bg-[#F5F5F4]"
    >
      <%= if Map.get(@category, :image_url) do %>
        <.optimized_image
          src={@category.image_url}
          alt={@category.name}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-700"
        />
      <% else %>
        <div class="absolute inset-0 bg-gradient-to-br from-[#1C1917] to-[#44403C]"></div>
      <% end %>
      <div class="absolute inset-0 bg-gradient-to-t from-[#1C1917]/70 to-transparent"></div>
      <div class="absolute inset-x-0 bottom-0 p-6 sm:p-8 text-white">
        <h3
          class="text-2xl sm:text-3xl mb-2 italic"
          style="font-family: 'Playfair Display', serif;"
        >
          {@category.name}
        </h3>
        <span
          class="inline-flex items-center gap-2 text-[10px] uppercase tracking-[0.25em] border-b border-white/40 pb-0.5 group-hover:border-white transition-colors"
          style="font-family: 'Inter', sans-serif;"
        >
          Discover →
        </span>
      </div>
    </a>
    """
  end

  # ── Featured piece ──

  defp featured_piece(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block group md:grid md:grid-cols-2 md:gap-12 lg:gap-20 items-center"
      aria-label={"Featured: #{@product.title}"}
    >
      <div class="aspect-[3/4] bg-white overflow-hidden mb-6 md:mb-0">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-700"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <span class="material-symbols-outlined text-7xl text-[#A8A29E]">apparel</span>
        </div>
      </div>
      <div class="md:px-6 lg:px-12">
        <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-4">
          The signature piece
        </p>
        <h2
          class="text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-[1.05] mb-6 italic"
          style="font-family: 'Playfair Display', serif;"
        >
          {@product.title}
        </h2>
        <p
          :if={@product.description}
          class="text-sm sm:text-base text-[#78716C] leading-relaxed font-light mb-8 max-w-md"
          style="font-family: 'Inter', sans-serif;"
        >
          {@product.description}
        </p>
        <p
          class="text-base text-[#1C1917] mb-8 tabular-nums tracking-wide"
          style="font-family: 'Inter', sans-serif;"
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span
          class="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.25em] text-[#1C1917] border-b border-[#1C1917]/30 pb-1 group-hover:border-[#1C1917] transition-colors"
          style="font-family: 'Inter', sans-serif;"
        >
          View piece →
        </span>
      </div>
    </a>
    """
  end

  # ── Helpers ──

  defp hero_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "The Sahel Edit"
    end
  end

  defp hero_subtitle(assigns) do
    case get_in(assigns, [:theme, :hero, :subtitle]) do
      sub when is_binary(sub) and sub != "" -> sub
      _ -> "Spring · Summer 2026"
    end
  end

  defp hero_image(assigns) do
    case get_in(assigns, [:theme, :hero, :image_url]) do
      url when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp lookbook_intro(%{description: desc}) when is_binary(desc) and desc != "" do
    String.slice(desc, 0, 240)
  end

  defp lookbook_intro(_),
    do:
      "An edit shaped by hand and held to a quieter standard. Made in limited runs by people we know by name."

  defp designer_quote(%{description: desc}) when is_binary(desc) and desc != "" do
    desc
    |> String.split(~r/[.!?]\s+/, parts: 2)
    |> List.first()
    |> String.trim()
  end

  defp designer_quote(_),
    do: "We make fewer things, and we make them very well."

  defp designer_location(store) do
    [Map.get(store, :city), Map.get(store, :region)]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
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
