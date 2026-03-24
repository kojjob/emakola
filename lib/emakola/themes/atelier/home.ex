defmodule Emakola.Themes.Atelier.Home do
  @moduledoc """
  Atelier theme home page renderer.

  Sections (gated by `@theme.sections`):
  - Hero: Full-screen editorial with gradient overlay, serif typography, gold accents
  - Categories: Asymmetric masonry grid
  - Products: 4-column featured grid with 5:6 cards
  - Brand Story: Split image + text section
  - Newsletter: Email signup CTA
  - Footer: Multi-column with store info
  """
  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  alias Emakola.Themes.Atelier.Shared

  @doc """
  Renders the full Atelier home page.

  Required assigns:
  - `@store` - Store struct
  - `@theme` - Theme config map with `:sections` map
  - `@products` - List of products
  - `@categories` - List of categories
  - `@cart_count` - Integer cart count
  """
  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :products, :list, default: []
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="atelier-body">
      <Shared.theme_styles theme={@theme} />
      <Shared.navbar store={@store} categories={@categories} cart_count={@cart_count} transparent={true} />

      <%!-- Hero Section --%>
      <.hero_section :if={section_enabled?(@theme, :hero)} store={@store} theme={@theme} />

      <%!-- Category Grid --%>
      <.categories_section
        :if={section_enabled?(@theme, :categories) && @categories != []}
        store={@store}
        categories={@categories}
      />

      <%!-- Featured Products --%>
      <.products_section
        :if={section_enabled?(@theme, :products) && @products != []}
        store={@store}
        products={@products}
      />

      <%!-- Brand Story --%>
      <.brand_story_section :if={section_enabled?(@theme, :brand_story)} store={@store} theme={@theme} />

      <%!-- Newsletter --%>
      <.newsletter_section :if={section_enabled?(@theme, :newsletter)} store={@store} />

      <%!-- Footer --%>
      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Hero Section ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  defp hero_section(assigns) do
    hero_image = get_in(assigns.theme, [:hero, :image_url]) || ""
    hero_subtitle = get_in(assigns.theme, [:hero, :subtitle]) || "Curated Collection"
    hero_title = get_in(assigns.theme, [:hero, :title]) || "The New\nEssential"
    hero_description = get_in(assigns.theme, [:hero, :description]) || "Redefining modern luxury through timeless silhouettes and conscious craft."

    assigns =
      assigns
      |> assign(:hero_image, hero_image)
      |> assign(:hero_subtitle, hero_subtitle)
      |> assign(:hero_title, hero_title)
      |> assign(:hero_description, hero_description)

    ~H"""
    <section class="relative min-h-screen flex items-end overflow-hidden">
      <%!-- Background Image --%>
      <img
        :if={@hero_image != ""}
        src={@hero_image}
        alt={"#{@store.name} collection"}
        class="absolute inset-0 w-full h-full object-cover object-center"
      />
      <div :if={@hero_image == ""} class="absolute inset-0 w-full h-full bg-stone-800"></div>

      <%!-- Gradient Overlay --%>
      <div class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/30 to-black/10"></div>

      <%!-- Content --%>
      <div class="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-20 sm:pb-28 lg:pb-32 w-full">
        <div class="max-w-2xl">
          <p
            class="text-xs sm:text-sm atelier-sans font-medium uppercase tracking-widest mb-4 sm:mb-6"
            style="color: var(--theme-primary);"
          >
            {@hero_subtitle}
          </p>
          <h1 class="atelier-serif text-5xl sm:text-6xl md:text-7xl lg:text-8xl text-white font-semibold leading-[0.95] mb-5 sm:mb-6">
            {raw(String.replace(@hero_title, "\n", "<br>"))}
          </h1>
          <p class="text-white/80 text-base sm:text-lg font-light leading-relaxed max-w-lg mb-8 sm:mb-10 atelier-sans">
            {@hero_description}
          </p>
          <div class="flex flex-col sm:flex-row gap-4">
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center justify-center px-8 py-4 text-xs font-semibold uppercase tracking-widest transition-colors duration-300"
              style="background: var(--theme-primary); color: var(--theme-accent);"
            >
              Shop Collection
            </a>
          </div>
        </div>
      </div>

      <%!-- Scroll Indicator --%>
      <div class="absolute bottom-6 left-1/2 -translate-x-1/2 z-10 animate-bounce hidden sm:block">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="1.5" stroke-linecap="round">
          <path d="M12 5v14M5 12l7 7 7-7" />
        </svg>
      </div>
    </section>
    """
  end

  # ── Categories Section ──

  attr :store, :map, required: true
  attr :categories, :list, required: true

  defp categories_section(assigns) do
    # Build asymmetric layout: first 2 are tall left columns, 3rd is large center-right, 4th is wide bottom
    padded = assigns.categories ++ List.duplicate(nil, max(0, 4 - length(assigns.categories)))
    [cat1, cat2, cat3, cat4 | _] = padded
    assigns = assign(assigns, cat1: cat1, cat2: cat2, cat3: cat3, cat4: cat4)

    ~H"""
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 auto-rows-[200px] sm:auto-rows-[260px] lg:auto-rows-[280px]">
        <%!-- Left tall column 1 --%>
        <Shared.category_card
          :if={@cat1}
          category={@cat1}
          store={@store}
          class="row-span-2 col-span-1"
        />

        <%!-- Left tall column 2 --%>
        <Shared.category_card
          :if={@cat2}
          category={@cat2}
          store={@store}
          class="row-span-2 col-span-1"
        />

        <%!-- Large center-right --%>
        <Shared.category_card
          :if={@cat3}
          category={@cat3}
          store={@store}
          class="col-span-2 row-span-3"
        />

        <%!-- Wide bottom --%>
        <Shared.category_card
          :if={@cat4}
          category={@cat4}
          store={@store}
          class="col-span-2 row-span-1"
        />
      </div>
    </section>
    """
  end

  # ── Featured Products Section ──

  attr :store, :map, required: true
  attr :products, :list, required: true

  defp products_section(assigns) do
    ~H"""
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24">
      <div class="text-center mb-10 sm:mb-14">
        <h2 class="atelier-serif text-3xl sm:text-4xl lg:text-5xl font-semibold" style="color: var(--theme-ink);">
          Curated for You
        </h2>
        <p class="text-sm mt-3 max-w-md mx-auto" style="color: var(--theme-accent-secondary, #44403C);">
          Handpicked pieces from our latest collections.
        </p>
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        <Shared.product_card
          :for={product <- Enum.take(@products, 8)}
          product={product}
          store={@store}
        />
      </div>

      <div :if={length(@products) > 8} class="text-center mt-10">
        <a
          href={"/s/#{@store.slug}/products"}
          class="inline-block text-xs font-semibold uppercase tracking-widest border-b-2 pb-1 transition-colors duration-300"
          style="color: var(--theme-ink); border-color: var(--theme-ink);"
        >
          View All Products
        </a>
      </div>
    </section>
    """
  end

  # ── Brand Story Section ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  defp brand_story_section(assigns) do
    story_image = get_in(assigns.theme, [:brand_story, :image_url]) || ""
    story_since = get_in(assigns.theme, [:brand_story, :since]) || ""
    story_title = get_in(assigns.theme, [:brand_story, :title]) || "Our Story"
    story_text = get_in(assigns.theme, [:brand_story, :text]) || assigns.store.description || ""

    assigns =
      assigns
      |> assign(:story_image, story_image)
      |> assign(:story_since, story_since)
      |> assign(:story_title, story_title)
      |> assign(:story_text, story_text)

    ~H"""
    <section class="bg-white">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <%!-- Image --%>
          <div class="overflow-hidden">
            <img
              :if={@story_image != ""}
              src={@story_image}
              alt={"#{@store.name} story"}
              class="w-full h-[400px] sm:h-[500px] object-cover"
              loading="lazy"
            />
            <div
              :if={@story_image == ""}
              class="w-full h-[400px] sm:h-[500px] bg-stone-200 flex items-center justify-center"
            >
              <span class="atelier-serif text-4xl text-stone-400">{String.first(@store.name)}</span>
            </div>
          </div>

          <%!-- Text --%>
          <div class="max-w-lg">
            <p
              :if={@story_since != ""}
              class="text-xs font-medium uppercase tracking-widest mb-4"
              style="color: var(--theme-primary);"
            >
              {@story_since}
            </p>
            <h2
              class="atelier-serif text-3xl sm:text-4xl lg:text-5xl font-semibold mb-6 leading-tight"
              style="color: var(--theme-ink);"
            >
              {@story_title}
            </h2>
            <p
              :if={@story_text != ""}
              class="text-base leading-relaxed mb-8"
              style="color: var(--theme-accent-secondary, #44403C);"
            >
              {@story_text}
            </p>
            <a
              href={"/s/#{@store.slug}/about"}
              class="inline-block text-xs font-semibold uppercase tracking-widest border-b-2 pb-1 transition-colors duration-300"
              style="color: var(--theme-ink); border-color: var(--theme-ink);"
            >
              Learn More
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ── Newsletter Section ──

  attr :store, :map, required: true

  defp newsletter_section(assigns) do
    ~H"""
    <section class="bg-stone-100/60">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div class="max-w-xl mx-auto text-center">
          <h2
            class="atelier-serif text-3xl sm:text-4xl lg:text-5xl font-semibold mb-4"
            style="color: var(--theme-ink);"
          >
            Join the Inner Circle
          </h2>
          <p class="text-sm sm:text-base leading-relaxed mb-8" style="color: var(--theme-accent-secondary, #44403C);">
            Early access to new collections, exclusive offers, and editorial content.
          </p>
          <form class="flex flex-col sm:flex-row gap-3 mb-4" phx-submit="subscribe_newsletter">
            <label for="newsletter-email" class="sr-only">Email address</label>
            <input
              id="newsletter-email"
              type="email"
              name="email"
              placeholder="Your email address"
              required
              class="flex-1 px-5 py-3.5 bg-white border border-stone-200 text-sm focus:outline-none focus:ring-2 focus:border-transparent transition-shadow"
              style="color: var(--theme-ink); focus:ring-color: var(--theme-primary);"
            />
            <button
              type="submit"
              class="px-8 py-3.5 text-xs font-semibold uppercase tracking-widest transition-colors duration-300 whitespace-nowrap"
              style="background: var(--theme-primary); color: var(--theme-accent);"
            >
              Subscribe
            </button>
          </form>
        </div>
      </div>
    </section>
    """
  end

  # ── Helpers ──

  defp section_enabled?(theme, section_name) do
    case get_in(theme, [:sections, section_name]) do
      false -> false
      _ -> true
    end
  end
end
