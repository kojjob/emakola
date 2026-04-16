defmodule Emakola.Themes.Bold.Shared do
  @moduledoc """
  Shared components for the Bold theme.

  Editorial, typography-forward, high-contrast magazine-style design with:
  - Slate-50 (#F8FAFC) off-white background
  - Slate-900 (#0F172A) primary / amber-500 (#F59E0B) accent
  - Outfit headings (bold geometric sans) + Inter body
  - No-border product cards, full-bleed images, editorial typography
  - Dark nav and footer, minimal chrome
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── CSS Variable Injection ──

  @doc """
  Injects theme CSS custom properties into the page as a <style> block.
  Place this as the first element inside the outermost div of each page.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#0F172A" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#F59E0B" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#F8FAFC" %>;
      }
    </style>
    """
  end

  # ── Bold Nav Bar ──

  @doc """
  Dark editorial navigation bar with store name in bold uppercase and minimal icons.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def bold_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50">
      <div class="bg-[#0F172A]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14 sm:h-16">
            <a
              href={"/s/#{@store.slug}"}
              class="text-sm sm:text-base font-bold tracking-[0.2em] uppercase text-white hover:text-[#F59E0B] transition-colors"
              style="font-family: 'Outfit', sans-serif;"
            >
              {@store.name}
            </a>

            <nav class="hidden sm:flex items-center gap-8" aria-label="Main navigation">
              <a
                href={"/s/#{@store.slug}/products"}
                class="text-sm font-medium text-slate-300 hover:text-white transition-colors tracking-wide uppercase"
                style="font-family: 'Inter', sans-serif;"
              >
                Shop
              </a>
            </nav>

            <div class="flex items-center gap-1">
              <a
                href={"/s/#{@store.slug}/products"}
                class="p-2.5 text-slate-400 hover:text-white transition-colors"
                aria-label="Search products"
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
                    d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                  />
                </svg>
              </a>
              <a
                href={"/s/#{@store.slug}/cart"}
                class="relative p-2.5 text-slate-400 hover:text-white transition-colors"
                aria-label={"Shopping cart, #{@cart_count} items"}
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
                    d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                  />
                </svg>
                <span
                  :if={@cart_count > 0}
                  class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[#F59E0B] text-[#0F172A] text-[10px] font-bold rounded-full flex items-center justify-center px-1"
                >
                  {@cart_count}
                </span>
              </a>
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Product Card (Editorial) ──

  @doc """
  Editorial product card: no border, full-width image, bold title, price underneath.
  Hover scales the image up subtly.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative overflow-hidden mb-4 bg-[#F1F5F9]">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full aspect-[3/4] object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <div :if={!@image} class="w-full aspect-[3/4] flex items-center justify-center bg-[#F1F5F9]">
          <svg class="w-12 h-12 text-[#94A3B8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        </div>
      </div>
      <h3
        class="text-base font-bold text-[#0F172A] leading-tight mb-1 truncate"
        style="font-family: 'Outfit', sans-serif;"
      >
        {@product.title}
      </h3>
      <p class="text-sm text-[#64748B]" style="font-family: 'Inter', sans-serif;">
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
    """
  end

  # ── Category Tag (Editorial Underlined Link) ──

  @doc """
  Category displayed as an underlined text link in editorial style.
  """
  attr :category, :map, required: true
  attr :store_slug, :string, required: true
  attr :active, :boolean, default: false

  def category_tag(assigns) do
    ~H"""
    <a
      href={"/s/#{@store_slug}/category/#{@category.slug}"}
      class={[
        "text-sm font-medium tracking-wide uppercase transition-colors",
        "border-b-2 pb-0.5",
        if(@active,
          do: "text-[#0F172A] border-[#F59E0B]",
          else: "text-[#64748B] border-transparent hover:text-[#0F172A] hover:border-[#0F172A]"
        )
      ]}
      style="font-family: 'Inter', sans-serif;"
    >
      {@category.name}
    </a>
    """
  end

  # ── Footer (Dark Editorial) ──

  @doc """
  Dark slate-900 footer with columns layout: Store info, Quick Links, Contact.
  Amber accent on hover.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[#0F172A] text-slate-400">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-10">
          <%!-- Store Info --%>
          <div class="lg:col-span-1">
            <h3
              class="text-base font-bold tracking-[0.15em] uppercase text-white mb-4"
              style="font-family: 'Outfit', sans-serif;"
            >
              {@store.name}
            </h3>
            <p class="text-sm leading-relaxed" style="font-family: 'Inter', sans-serif;">
              {if @store.description,
                do: @store.description,
                else: "Curated goods for the discerning eye."}
            </p>
          </div>

          <%!-- Quick Links --%>
          <div>
            <h4
              class="text-xs font-bold tracking-[0.2em] uppercase text-slate-500 mb-4"
              style="font-family: 'Outfit', sans-serif;"
            >
              Quick Links
            </h4>
            <ul class="space-y-3 text-sm" style="font-family: 'Inter', sans-serif;">
              <li>
                <a
                  href={"/s/#{@store.slug}/products"}
                  class="hover:text-[#F59E0B] transition-colors"
                >
                  Shop All
                </a>
              </li>
              <li :for={cat <- Enum.take(@categories, 4)}>
                <a
                  href={"/s/#{@store.slug}/category/#{cat.slug}"}
                  class="hover:text-[#F59E0B] transition-colors"
                >
                  {cat.name}
                </a>
              </li>
            </ul>
          </div>

          <%!-- Contact --%>
          <div>
            <h4
              class="text-xs font-bold tracking-[0.2em] uppercase text-slate-500 mb-4"
              style="font-family: 'Outfit', sans-serif;"
            >
              Contact
            </h4>
            <ul class="space-y-3 text-sm" style="font-family: 'Inter', sans-serif;">
              <li :if={Map.get(@store, :whatsapp_number)}>
                <a
                  href={"https://wa.me/#{String.replace(@store.whatsapp_number || "", "+", "")}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="hover:text-[#F59E0B] transition-colors"
                >
                  WhatsApp
                </a>
              </li>
              <li :if={Map.get(@store, :email)}>
                <a
                  href={"mailto:#{@store.email}"}
                  class="hover:text-[#F59E0B] transition-colors"
                >
                  {@store.email}
                </a>
              </li>
            </ul>
          </div>

          <%!-- Newsletter Mini --%>
          <div>
            <h4
              class="text-xs font-bold tracking-[0.2em] uppercase text-slate-500 mb-4"
              style="font-family: 'Outfit', sans-serif;"
            >
              Newsletter
            </h4>
            <p class="text-sm mb-4" style="font-family: 'Inter', sans-serif;">
              New drops and editorial picks.
            </p>
            <form phx-submit="subscribe_newsletter" class="flex">
              <input
                type="email"
                name="email"
                placeholder="Email"
                required
                class="flex-1 px-4 py-2.5 bg-slate-800 text-white placeholder:text-slate-500 text-sm border border-slate-700 focus:outline-none focus:border-[#F59E0B] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              />
              <button
                type="submit"
                class="px-5 py-2.5 bg-[#F59E0B] text-[#0F172A] text-sm font-bold hover:bg-[#D97706] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Go
              </button>
            </form>
          </div>
        </div>

        <div class="border-t border-slate-800 mt-12 pt-8 text-center text-xs text-slate-600">
          <p style="font-family: 'Inter', sans-serif;">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
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
end
