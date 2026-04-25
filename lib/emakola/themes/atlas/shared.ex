defmodule Emakola.Themes.Atlas.Shared do
  @moduledoc """
  Shared components for the Atlas theme.

  Catalog-driven design with:
  - Off-white (#FAFAFA) background
  - Slate-900 (#0F172A) text + royal blue (#2563EB) accent
  - Inter throughout, JetBrains Mono for prices
  - Persistent left sidebar (desktop) with category tree + News block
  - shelf_card with color-coded pill price + swatch dots
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # Cycle through these pill colors so a product grid breathes with colour.
  @pill_palette [
    %{bg: "#EC4899", text: "#FFFFFF"},
    %{bg: "#0EA5E9", text: "#FFFFFF"},
    %{bg: "#EF4444", text: "#FFFFFF"},
    %{bg: "#A855F7", text: "#FFFFFF"},
    %{bg: "#F97316", text: "#FFFFFF"},
    %{bg: "#10B981", text: "#FFFFFF"}
  ]

  # ── Theme Styles ──

  @doc """
  Injects a <style> block with CSS custom properties for the Atlas theme.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#0F172A" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#2563EB" %>;
        --theme-highlight: <%= get_in(@theme, [:colors, :highlight]) || "#F1F5F9" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#FAFAFA" %>;
      }
    </style>
    """
  end

  # ── Atlas Nav Bar ──

  @doc """
  Top navigation with brand left, primary categories centred, account/bag right.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def atlas_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-white/95 backdrop-blur-md border-b border-[#E2E8F0]">
      <div class="max-w-[1400px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-14 sm:h-16">
          <a href={"/s/#{@store.slug}"} class="flex items-center min-w-0">
            <span
              class="text-base font-bold text-[#0F172A] tracking-tight truncate uppercase"
              style="font-family: 'Inter', sans-serif;"
            >
              {@store.name}
            </span>
          </a>

          <nav class="hidden md:flex items-center gap-6" aria-label="Primary">
            <a
              :for={category <- Enum.take(@categories, 4)}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class="text-sm text-[#0F172A] hover:text-[var(--theme-accent,#2563EB)] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              {category.name}
            </a>
          </nav>

          <div class="flex items-center gap-4">
            <div class="hidden lg:flex items-center bg-[#F1F5F9] rounded-full px-3 py-1.5 border border-[#E2E8F0]">
              <svg
                class="w-4 h-4 text-[#64748B]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                />
              </svg>
              <input
                type="text"
                placeholder="Search"
                class="bg-transparent border-0 focus:outline-none focus:ring-0 text-sm text-[#0F172A] placeholder:text-[#94A3B8] ml-2 w-32"
                style="font-family: 'Inter', sans-serif;"
              />
            </div>

            <a
              href={"/s/#{@store.slug}/wishlist"}
              class="hidden sm:inline-flex p-2 text-[#64748B] hover:text-[#0F172A] transition-colors"
              aria-label="Wishlist"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
                />
              </svg>
            </a>
            <a
              href={"/s/#{@store.slug}/cart"}
              class="relative inline-flex items-center gap-1.5 bg-[#F1F5F9] hover:bg-[#E2E8F0] rounded-full pl-3 pr-3.5 py-1.5 text-sm text-[#0F172A] transition-colors"
              style="font-family: 'Inter', sans-serif;"
              aria-label={"Bag, #{@cart_count} items"}
            >
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
                  d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007z"
                />
              </svg>
              Bag
              <span
                :if={@cart_count > 0}
                class="text-xs font-semibold tabular-nums"
                style="font-family: 'JetBrains Mono', monospace;"
              >
                {@cart_count}
              </span>
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Sidebar ──

  @doc """
  Persistent left sidebar with collapsible category tree and a "Stories"
  block. Renders the active category expanded; other categories show as
  collapsed list items with item counts where available.
  """
  attr :store, :map, required: true
  attr :categories, :list, required: true
  attr :active_category, :map, default: nil

  def sidebar(assigns) do
    ~H"""
    <aside
      class="hidden lg:block w-60 flex-shrink-0 bg-[#F1F5F9] border-r border-[#E2E8F0] py-6"
      aria-label="Catalog navigation"
    >
      <nav class="px-5">
        <p
          class="text-[10px] font-semibold tracking-[0.2em] uppercase text-[#94A3B8] mb-3"
          style="font-family: 'Inter', sans-serif;"
        >
          Browse
        </p>
        <ul class="space-y-1" role="list">
          <li :for={category <- @categories}>
            <a
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class={[
                "flex items-center justify-between gap-2 px-2 py-1.5 rounded-md text-sm transition-colors",
                if(active?(category, @active_category),
                  do: "bg-white text-[#0F172A] font-semibold",
                  else: "text-[#475569] hover:bg-white hover:text-[#0F172A]"
                )
              ]}
              style="font-family: 'Inter', sans-serif;"
            >
              <span class="truncate">{category.name}</span>
              <span
                :if={category_count(category)}
                class="text-[10px] tabular-nums text-[#94A3B8]"
                style="font-family: 'JetBrains Mono', monospace;"
              >
                {category_count(category)}
              </span>
            </a>
          </li>
        </ul>
      </nav>

      <div class="mt-8 pt-6 px-5 border-t border-[#E2E8F0]">
        <p
          class="text-[10px] font-semibold tracking-[0.2em] uppercase text-[#94A3B8] mb-3"
          style="font-family: 'Inter', sans-serif;"
        >
          News & Stories
        </p>
        <ul class="space-y-3" role="list">
          <li>
            <a href="#" class="block group">
              <p
                class="text-sm text-[#0F172A] group-hover:text-[var(--theme-accent,#2563EB)] transition-colors leading-snug"
                style="font-family: 'Inter', sans-serif;"
              >
                The basics of buying for your store
              </p>
              <p
                class="text-[11px] text-[#94A3B8] mt-1"
                style="font-family: 'JetBrains Mono', monospace;"
              >
                09 Jul
              </p>
            </a>
          </li>
          <li>
            <a href="#" class="block group">
              <p
                class="text-sm text-[#0F172A] group-hover:text-[var(--theme-accent,#2563EB)] transition-colors leading-snug"
                style="font-family: 'Inter', sans-serif;"
              >
                Consumer trends in West African retail
              </p>
              <p
                class="text-[11px] text-[#94A3B8] mt-1"
                style="font-family: 'JetBrains Mono', monospace;"
              >
                09 Jul
              </p>
            </a>
          </li>
          <li>
            <a
              href="#"
              class="text-xs text-[var(--theme-accent,#2563EB)] hover:underline"
              style="font-family: 'Inter', sans-serif;"
            >
              View more →
            </a>
          </li>
        </ul>
      </div>
    </aside>
    """
  end

  # ── Shelf Card ──

  @doc """
  Catalog-style product card with white frame, color-coded pill price, and
  optional color swatch dots. `color_index` cycles the pill palette so
  consecutive cards in a grid show varied colours.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :color_index, :integer, default: 0
  attr :swatches, :list, default: []

  def shelf_card(assigns) do
    image = first_image(assigns.product)
    pill = pill_for(assigns.color_index)

    assigns =
      assigns
      |> assign(:image, image)
      |> assign(:pill, pill)

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group block bg-white rounded-2xl border border-[#E2E8F0] hover:border-[var(--theme-accent,#2563EB)] transition-colors overflow-hidden"
    >
      <p
        class="text-center text-sm text-[#0F172A] pt-5 pb-2 px-3 truncate"
        style="font-family: 'Inter', sans-serif;"
      >
        {@product.title}
      </p>
      <div class="aspect-square px-6 py-2 flex items-center justify-center">
        <%= if @image do %>
          <.optimized_image
            src={@image}
            alt={@product.title}
            class="max-w-full max-h-full object-contain group-hover:scale-[1.05] transition-transform duration-300"
          />
        <% else %>
          <span class="material-symbols-outlined text-5xl text-[#CBD5E1]">shopping_bag</span>
        <% end %>
      </div>
      <div class="flex flex-col items-center gap-2 px-3 pb-5">
        <span
          class="inline-flex items-center px-3.5 py-1 rounded-full text-xs font-semibold tabular-nums"
          style={"background-color: #{@pill.bg}; color: #{@pill.text}; font-family: 'JetBrains Mono', monospace;"}
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </span>
        <div :if={@swatches != []} class="flex items-center gap-1.5">
          <span
            :for={hex <- Enum.take(@swatches, 4)}
            class="block w-2 h-2 rounded-full"
            style={"background-color: #{hex};"}
            aria-hidden="true"
          >
          </span>
        </div>
      </div>
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Atlas catalog footer.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-white border-t border-[#E2E8F0] mt-12">
      <div class="max-w-[1400px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14">
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-8">
          <div>
            <p
              class="text-base font-bold text-[#0F172A] mb-3 uppercase tracking-tight"
              style="font-family: 'Inter', sans-serif;"
            >
              {@store.name}
            </p>
            <p
              :if={@store.description}
              class="text-xs text-[#64748B] leading-relaxed"
              style="font-family: 'Inter', sans-serif;"
            >
              {String.slice(@store.description, 0, 120)}
            </p>
          </div>

          <div>
            <p
              class="text-[10px] font-semibold tracking-[0.2em] uppercase text-[#0F172A] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Shop
            </p>
            <ul class="space-y-2 text-sm text-[#475569]" style="font-family: 'Inter', sans-serif;">
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-[#0F172A] transition-colors">
                  All products
                </a>
              </li>
              <li><a href="#" class="hover:text-[#0F172A] transition-colors">Gift cards</a></li>
              <li><a href="#" class="hover:text-[#0F172A] transition-colors">Find a store</a></li>
            </ul>
          </div>

          <div>
            <p
              class="text-[10px] font-semibold tracking-[0.2em] uppercase text-[#0F172A] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Service
            </p>
            <ul class="space-y-2 text-sm text-[#475569]" style="font-family: 'Inter', sans-serif;">
              <li>
                <a href="#" class="hover:text-[#0F172A] transition-colors">Returns & exchanges</a>
              </li>
              <li><a href="#" class="hover:text-[#0F172A] transition-colors">Booking</a></li>
              <li :if={Map.get(@store, :contact_email)}>
                <a
                  href={"mailto:#{@store.contact_email}"}
                  class="hover:text-[#0F172A] transition-colors"
                >
                  Contact
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p
              class="text-[10px] font-semibold tracking-[0.2em] uppercase text-[#0F172A] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Pay with
            </p>
            <div class="flex flex-wrap gap-1.5">
              <span class="inline-flex items-center px-2 py-1 rounded bg-[#FFC107] text-[#0F172A] text-[10px] font-bold">
                MoMo
              </span>
              <span class="inline-flex items-center px-2 py-1 rounded bg-[#E60000] text-white text-[10px] font-bold">
                Vodafone
              </span>
              <span class="inline-flex items-center px-2 py-1 rounded bg-[#0F172A] text-white text-[10px] font-bold">
                Card
              </span>
            </div>
          </div>
        </div>

        <div
          class="mt-10 pt-5 border-t border-[#E2E8F0] text-xs text-[#94A3B8]"
          style="font-family: 'Inter', sans-serif;"
        >
          © {Date.utc_today().year} {@store.name}. Powered by Emakola.
        </div>
      </div>
    </footer>
    """
  end

  # ── Helpers ──

  @doc """
  Extract first image URL from a product's images association.
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc """
  Pick a pill color by index, cycling through the palette.
  """
  def pill_for(index) when is_integer(index) do
    Enum.at(@pill_palette, rem(abs(index), length(@pill_palette)))
  end

  def pill_for(_), do: hd(@pill_palette)

  defp category_count(category) do
    case Map.get(category, :item_count) do
      n when is_integer(n) and n > 0 -> n
      _ -> nil
    end
  end

  defp active?(_category, nil), do: false
  defp active?(%{slug: slug}, %{slug: active_slug}), do: slug == active_slug
  defp active?(_, _), do: false
end
