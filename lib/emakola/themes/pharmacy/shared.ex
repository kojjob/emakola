defmodule Emakola.Themes.Pharmacy.Shared do
  @moduledoc """
  Shared components for the Pharmacy theme: theme_styles injection,
  pharmacy_nav (white bar with mint search), pharmacy_footer (forest
  green, matches hero), and image helpers.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  # ── CSS Variable Injection ──

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#14543E" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#A7E5C5" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#F9F6F0" %>;
        --theme-surface: <%= get_in(@theme, [:colors, :surface]) || "#FFFFFF" %>;
      }
      .pharmacy-body { font-family: 'Inter', sans-serif; color: #1F2937; background: var(--theme-bg); }
      .pharmacy-heading { font-family: 'Fraunces', serif; letter-spacing: -0.01em; }
      .pharmacy-pill { border-radius: 9999px; }
      .pharmacy-card { background: var(--theme-surface); border-radius: 16px; box-shadow: 0 1px 3px rgba(20,84,62,0.06); }
    </style>
    """
  end

  # ── Pharmacy Navbar ──

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def pharmacy_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-[#F9F6F0]/95 backdrop-blur-md border-b border-[#E5E7EB]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 sm:h-20">
          <%!-- Brand --%>
          <a href={"/s/#{@store.slug}"} class="flex items-center gap-3 min-w-0">
            <div class="w-10 h-10 rounded-full bg-[#14543E] flex items-center justify-center flex-shrink-0">
              <span class="material-symbols-outlined text-[#A7E5C5]" style="font-size: 22px;">
                medical_services
              </span>
            </div>
            <span class="text-xl sm:text-2xl font-semibold text-[#14543E] truncate pharmacy-heading">
              {@store.name}
            </span>
          </a>

          <%!-- Desktop nav --%>
          <nav class="hidden md:flex items-center gap-8 text-sm font-medium text-[#1F2937]">
            <a href={"/s/#{@store.slug}"} class="hover:text-[#14543E] transition-colors">Home</a>
            <a href={"/s/#{@store.slug}/products"} class="hover:text-[#14543E] transition-colors">
              Products
            </a>
            <a
              href={"/s/#{@store.slug}/products"}
              class="hover:text-[#14543E] transition-colors"
            >
              Categories
            </a>
            <a href={"/s/#{@store.slug}/about"} class="hover:text-[#14543E] transition-colors">
              About
            </a>
            <a href={"/s/#{@store.slug}/contact"} class="hover:text-[#14543E] transition-colors">
              Contact
            </a>
          </nav>

          <%!-- Right cluster --%>
          <div class="flex items-center gap-2 sm:gap-3">
            <a
              href={"/s/#{@store.slug}/cart"}
              class="relative w-11 h-11 rounded-full hover:bg-[#A7E5C5]/30 flex items-center justify-center transition-colors"
              aria-label={"Cart, #{@cart_count} items"}
            >
              <span class="material-symbols-outlined text-[#14543E]" style="font-size: 22px;">
                shopping_bag
              </span>
              <span
                :if={@cart_count > 0}
                class="absolute -top-1 -right-1 min-w-[20px] h-5 px-1 rounded-full bg-[#14543E] text-white text-[10px] font-bold flex items-center justify-center"
              >
                {@cart_count}
              </span>
            </a>
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden sm:inline-flex items-center px-5 py-2.5 rounded-full bg-[#14543E] text-white text-sm font-semibold hover:bg-[#0F3F2E] transition-colors min-h-[44px]"
            >
              Shop Now
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Pharmacy Footer ──

  attr :store, :map, required: true

  def pharmacy_footer(assigns) do
    ~H"""
    <footer class="bg-[#14543E] text-[#F9F6F0]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-10">
          <div>
            <div class="flex items-center gap-3 mb-4">
              <div class="w-10 h-10 rounded-full bg-[#A7E5C5] flex items-center justify-center">
                <span class="material-symbols-outlined text-[#14543E]" style="font-size: 22px;">
                  medical_services
                </span>
              </div>
              <span class="text-xl font-semibold pharmacy-heading">{@store.name}</span>
            </div>
            <p class="text-sm text-[#F9F6F0]/80 leading-relaxed">
              {@store.description ||
                "Verified pharmacy. Genuine medicines. Discreet delivery across Ghana."}
            </p>
          </div>

          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#A7E5C5]">
              Shop
            </h4>
            <ul class="space-y-3 text-sm text-[#F9F6F0]/80">
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  All Products
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  Medicines
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  Wellness
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  Supplements
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#A7E5C5]">
              Help
            </h4>
            <ul class="space-y-3 text-sm text-[#F9F6F0]/80">
              <li>
                <a href={"/s/#{@store.slug}/about"} class="hover:text-white transition-colors">
                  About us
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/contact"} class="hover:text-white transition-colors">
                  Contact
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/blog"} class="hover:text-white transition-colors">
                  Health blog
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#A7E5C5]">
              Trust
            </h4>
            <ul class="space-y-3 text-sm text-[#F9F6F0]/80">
              <li class="flex items-center gap-2">
                <span class="material-symbols-outlined" style="font-size: 16px;">verified_user</span>
                Licensed pharmacy
              </li>
              <li class="flex items-center gap-2">
                <span class="material-symbols-outlined" style="font-size: 16px;">local_pharmacy</span>
                Genuine medicines
              </li>
              <li class="flex items-center gap-2">
                <span class="material-symbols-outlined" style="font-size: 16px;">local_shipping</span>
                Discreet delivery
              </li>
            </ul>
          </div>
        </div>

        <div class="border-t border-[#F9F6F0]/15 mt-12 pt-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-[#F9F6F0]/60">
          <p>&copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.</p>
          <p>Designed by Emakola</p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Image Helpers ──

  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

  def category_image(category) do
    if Map.has_key?(category, :image_url), do: category.image_url, else: nil
  end

  # ── Product Card Helper (used by Home + ProductList) ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :compact, :boolean, default: false

  def product_card(assigns) do
    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="pharmacy-card group block overflow-hidden hover:shadow-md transition-shadow"
    >
      <div class="aspect-square bg-[#F9F6F0] flex items-center justify-center overflow-hidden">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-contain p-4 group-hover:scale-105 transition-transform duration-300"
        />
        <span
          :if={!first_image(@product)}
          class="material-symbols-outlined text-[#A7E5C5]"
          style="font-size: 56px;"
        >
          medication
        </span>
      </div>
      <div class="p-4 sm:p-5">
        <%!-- Static rating placeholder — swap to real reviews aggregate when available --%>
        <div class="flex items-center gap-1 mb-1.5">
          <span :for={_ <- 1..5} class="text-[#FBBF24]" style="font-size: 14px;">★</span>
          <span class="text-[10px] text-[#6B7280] ml-1">(4.8)</span>
        </div>
        <h3 class="text-sm font-semibold text-[#1F2937] line-clamp-2 mb-1.5 min-h-[2.5rem]">
          {@product.title}
        </h3>
        <div class="flex items-center justify-between mt-3">
          <span class="text-base font-bold text-[#14543E]">
            {EmakolaWeb.Helpers.Currency.format_price(
              @product.min_price || 0,
              Map.get(@store, :currency, "GHS")
            )}
          </span>
          <span class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-[#A7E5C5] text-[#14543E] text-xs font-bold hover:bg-[#8DD4B0] transition-colors">
            <span class="material-symbols-outlined" style="font-size: 14px;">add_shopping_cart</span>
            Add
          </span>
        </div>
      </div>
    </a>
    """
  end
end
