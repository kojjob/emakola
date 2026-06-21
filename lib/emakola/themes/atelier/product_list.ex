defmodule Emakola.Themes.Atelier.ProductList do
  @moduledoc """
  Atelier theme product listing / shop-all page renderer.

  Features:
  - Clean product grid (2-col mobile, 3-col tablet, 4-col desktop)
  - Filter sidebar with categories
  - Search input
  - Atelier editorial styling with serif headings
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Atelier.Shared

  @doc """
  Renders the Atelier shop/product listing page.

  Required assigns:
  - `@store` - Store struct
  - `@theme` - Theme config map
  - `@products` - List of products to display
  - `@categories` - List of categories for filtering
  - `@cart_count` - Integer cart count
  - `@active_category` - Currently selected category slug (or nil)
  - `@search_query` - Current search query string (or nil)
  """
  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :products, :list, default: []
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :active_category, :string, default: nil
  attr :search_query, :string, default: nil

  def render(assigns) do
    ~H"""
    <div class="atelier-body">
      <Shared.theme_styles theme={@theme} />
      <Shared.navbar
        store={@store}
        categories={@categories}
        cart_count={@cart_count}
        transparent={false}
      />

      <%!-- Page Header --%>
      <div class="pt-24 pb-8 sm:pt-28 sm:pb-12" style="background: var(--theme-surface);">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1
            class="atelier-serif text-3xl sm:text-4xl lg:text-5xl font-semibold text-center"
            style="color: var(--theme-ink);"
          >
            {if @active_category, do: category_title(@categories, @active_category), else: "Shop All"}
          </h1>
          <p
            :if={@search_query && @search_query != ""}
            class="text-sm text-center mt-2"
            style="color: var(--theme-accent-secondary, #44403C);"
          >
            Results for "<span class="font-medium">{@search_query}</span>"
          </p>
        </div>
      </div>

      <%!-- Main Content --%>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24">
        <div class="lg:grid lg:grid-cols-[240px_1fr] lg:gap-10">
          <%!-- Sidebar (Desktop) --%>
          <aside class="hidden lg:block pt-2">
            <.filter_sidebar
              store={@store}
              categories={@categories}
              active_category={@active_category}
              search_query={@search_query}
            />
          </aside>

          <%!-- Products --%>
          <div>
            <%!-- Mobile Search + Filter Row --%>
            <div class="lg:hidden mb-6">
              <.search_bar store={@store} search_query={@search_query} />
              <.mobile_category_pills
                store={@store}
                categories={@categories}
                active_category={@active_category}
              />
            </div>

            <%!-- Product Count --%>
            <div class="flex items-center justify-between mb-6">
              <p
                class="text-xs uppercase tracking-widest"
                style="color: var(--theme-accent-secondary, #44403C);"
              >
                {length(@products)} {if length(@products) == 1, do: "product", else: "products"}
              </p>
            </div>

            <%!-- Product Grid --%>
            <div
              :if={@products != []}
              class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-3 gap-4 sm:gap-6"
            >
              <Shared.product_card
                :for={product <- @products}
                product={product}
                store={@store}
              />
            </div>

            <%!-- Empty State --%>
            <div :if={@products == []} class="text-center py-20">
              <p class="atelier-serif text-2xl font-semibold mb-2" style="color: var(--theme-ink);">
                No products found
              </p>
              <p class="text-sm" style="color: var(--theme-accent-secondary, #44403C);">
                Try adjusting your search or browse all categories.
              </p>
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-block mt-6 text-xs font-semibold uppercase tracking-widest border-b-2 pb-1 transition-colors duration-300"
                style="color: var(--theme-ink); border-color: var(--theme-ink);"
              >
                View All
              </a>
            </div>
          </div>
        </div>
      </div>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Filter Sidebar ──

  attr :store, :map, required: true
  attr :categories, :list, required: true
  attr :active_category, :string, default: nil
  attr :search_query, :string, default: nil

  defp filter_sidebar(assigns) do
    ~H"""
    <div>
      <%!-- Search --%>
      <.search_bar store={@store} search_query={@search_query} />

      <%!-- Categories --%>
      <div class="mt-8">
        <h3
          class="text-[11px] font-semibold uppercase tracking-widest mb-4"
          style="color: var(--theme-ink);"
        >
          Categories
        </h3>
        <ul class="space-y-2">
          <li>
            <a
              href={store_path(@store.slug, "/products")}
              class={"text-sm transition-colors duration-200 " <> if(is_nil(@active_category), do: "font-semibold", else: "")}
              style={"color: " <> if(is_nil(@active_category), do: "var(--theme-ink)", else: "var(--theme-accent-secondary, #44403C)") <> ";"}
            >
              All Products
            </a>
          </li>
          <li :for={category <- @categories}>
            <a
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class={"text-sm transition-colors duration-200 " <> if(@active_category == category.slug, do: "font-semibold", else: "")}
              style={"color: " <> if(@active_category == category.slug, do: "var(--theme-ink)", else: "var(--theme-accent-secondary, #44403C)") <> ";"}
            >
              {category.name}
            </a>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  # ── Search Bar ──

  attr :store, :map, required: true
  attr :search_query, :string, default: nil

  defp search_bar(assigns) do
    ~H"""
    <form action={store_path(@store.slug, "/products")} method="get" class="relative">
      <input
        type="search"
        name="q"
        value={@search_query || ""}
        placeholder="Search products..."
        class="w-full pl-10 pr-4 py-3 bg-white border border-stone-200 text-sm focus:outline-none focus:ring-2 focus:border-transparent transition-shadow"
        style="color: var(--theme-ink);"
      />
      <svg
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4"
        style="color: var(--theme-accent-secondary, #44403C);"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
        viewBox="0 0 24 24"
      >
        <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
      </svg>
    </form>
    """
  end

  # ── Mobile Category Pills ──

  attr :store, :map, required: true
  attr :categories, :list, required: true
  attr :active_category, :string, default: nil

  defp mobile_category_pills(assigns) do
    ~H"""
    <div class="flex gap-2 overflow-x-auto py-4 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
      <a
        href={store_path(@store.slug, "/products")}
        class={"px-4 py-2 text-xs font-medium uppercase tracking-wider whitespace-nowrap border transition-colors " <>
          if(is_nil(@active_category),
            do: "border-current font-semibold",
            else: "border-stone-200"
          )}
        style={"color: " <> if(is_nil(@active_category), do: "var(--theme-ink)", else: "var(--theme-accent-secondary, #44403C)") <> ";"}
      >
        All
      </a>
      <a
        :for={category <- @categories}
        href={store_path(@store.slug, "/category/#{category.slug}")}
        class={"px-4 py-2 text-xs font-medium uppercase tracking-wider whitespace-nowrap border transition-colors " <>
          if(@active_category == category.slug,
            do: "border-current font-semibold",
            else: "border-stone-200"
          )}
        style={"color: " <> if(@active_category == category.slug, do: "var(--theme-ink)", else: "var(--theme-accent-secondary, #44403C)") <> ";"}
      >
        {category.name}
      </a>
    </div>
    """
  end

  # ── Helpers ──

  defp category_title(categories, slug) do
    case Enum.find(categories, fn c -> c.slug == slug end) do
      nil -> "Shop"
      category -> category.name
    end
  end
end
