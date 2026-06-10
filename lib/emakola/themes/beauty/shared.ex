defmodule Emakola.Themes.Beauty.Shared do
  @moduledoc """
  Shared components for the Beauty theme: theme_styles, beauty_nav
  (pill-nav inspired by ÉLAN BEAUTY), beauty_footer (warm walnut),
  product_card, image helpers.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#6B4423") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#C9925E") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#F5EFE5") %>;
        --theme-on-dark: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :on_dark]), "#FAF6EE") %>;
      }
      .beauty-body { font-family: 'Manrope', sans-serif; color: #3D2F25; background: var(--theme-bg); }
      .beauty-heading { font-family: 'Cormorant Garamond', serif; letter-spacing: -0.005em; }
      .beauty-card { background: #FFFFFF; border-radius: 18px; box-shadow: 0 1px 4px rgba(107,68,35,0.05); }
      .beauty-pill { border-radius: 9999px; }
    </style>
    """
  end

  # ── Beauty Navbar (pill nav, inspired by ÉLAN BEAUTY) ──

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :on_dark, :boolean, default: false

  def beauty_nav(assigns) do
    ~H"""
    <header class={"sticky top-0 z-50 " <> if(@on_dark, do: "bg-[#6B4423]/90 backdrop-blur-md", else: "bg-[#F5EFE5]/95 backdrop-blur-md border-b border-[#E8DBC8]")}>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 sm:h-20">
          <%!-- Brand --%>
          <a href={"/s/#{@store.slug}"} class="flex items-center gap-2 min-w-0">
            <span class={"text-lg sm:text-xl font-bold tracking-[0.2em] uppercase " <> if(@on_dark, do: "text-[#FAF6EE]", else: "text-[#6B4423]")}>
              {@store.name}
            </span>
          </a>

          <%!-- Pill nav --%>
          <nav class={"hidden md:flex items-center gap-1 px-2 py-1 rounded-full " <> if(@on_dark, do: "bg-white/10", else: "bg-white border border-[#E8DBC8]")}>
            <a
              :for={
                {label, path} <- [
                  {"Home", ""},
                  {"Shop", "/products"},
                  {"About", "/about"},
                  {"Journal", "/blog"},
                  {"Contact", "/contact"}
                ]
              }
              href={"/s/#{@store.slug}#{path}"}
              class={"px-4 py-2 rounded-full text-sm font-medium transition-colors " <> if(@on_dark, do: "text-[#FAF6EE]/80 hover:bg-white/10 hover:text-[#FAF6EE]", else: "text-[#3D2F25] hover:bg-[#F5EFE5]")}
            >
              {label}
            </a>
          </nav>

          <%!-- Right cluster --%>
          <div class="flex items-center gap-2 sm:gap-3">
            <a
              href={"/s/#{@store.slug}/cart"}
              class={"relative w-11 h-11 rounded-full flex items-center justify-center transition-colors " <> if(@on_dark, do: "hover:bg-white/10", else: "hover:bg-[#E8DBC8]/50")}
              aria-label={"Cart, #{@cart_count} items"}
            >
              <span
                class={"material-symbols-outlined " <> if(@on_dark, do: "text-[#FAF6EE]", else: "text-[#6B4423]")}
                style="font-size: 22px;"
              >
                shopping_bag
              </span>
              <span
                :if={@cart_count > 0}
                class="absolute -top-1 -right-1 min-w-[20px] h-5 px-1 rounded-full bg-[#C9925E] text-white text-[10px] font-bold flex items-center justify-center"
              >
                {@cart_count}
              </span>
            </a>
            <a
              href={"/s/#{@store.slug}/products"}
              class={"hidden sm:inline-flex items-center px-5 py-2.5 rounded-full text-sm font-semibold transition-colors min-h-[44px] " <> if(@on_dark, do: "bg-[#FAF6EE] text-[#6B4423] hover:bg-white", else: "bg-[#6B4423] text-[#FAF6EE] hover:bg-[#5A381D]")}
            >
              Book Now
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Beauty Footer ──

  attr :store, :map, required: true

  def beauty_footer(assigns) do
    ~H"""
    <footer class="bg-[#3D2F25] text-[#FAF6EE]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-10">
          <div class="md:col-span-2">
            <span class="text-2xl font-bold tracking-[0.2em] uppercase">{@store.name}</span>
            <p class="text-sm text-[#FAF6EE]/70 leading-relaxed mt-4 max-w-md">
              {@store.description ||
                "Botanical skincare and beauty essentials — crafted for melanin-rich skin."}
            </p>
          </div>

          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#C9925E]">
              Shop
            </h4>
            <ul class="space-y-3 text-sm text-[#FAF6EE]/70">
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  All products
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  Skincare
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  Hair
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  Body
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#C9925E]">
              Help
            </h4>
            <ul class="space-y-3 text-sm text-[#FAF6EE]/70">
              <li>
                <a href={"/s/#{@store.slug}/about"} class="hover:text-white transition-colors">
                  Our story
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/contact"} class="hover:text-white transition-colors">
                  Contact
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/blog"} class="hover:text-white transition-colors">
                  Journal
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="border-t border-[#FAF6EE]/15 mt-12 pt-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-[#FAF6EE]/50">
          <p>&copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.</p>
          <p>Crafted with care</p>
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

  # ── Product Card ──

  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="beauty-card group block overflow-hidden hover:shadow-md transition-shadow"
    >
      <div class="aspect-[4/5] bg-[#F5EFE5] flex items-center justify-center overflow-hidden">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <span
          :if={!first_image(@product)}
          class="material-symbols-outlined text-[#C9925E]/40"
          style="font-size: 64px;"
        >
          spa
        </span>
      </div>
      <div class="p-4 sm:p-5">
        <%!-- 5-star rating row --%>
        <div class="flex items-center gap-1 mb-2">
          <span :for={_ <- 1..5} class="text-[#C9925E]" style="font-size: 12px;">★</span>
          <span class="text-[10px] text-[#6B4423]/60 ml-1">(4.9)</span>
        </div>
        <h3 class="beauty-heading text-lg font-semibold text-[#3D2F25] line-clamp-2 mb-2 leading-snug min-h-[3rem]">
          {@product.title}
        </h3>
        <div class="flex items-center justify-between">
          <span class="text-base font-bold text-[#6B4423]">
            {EmakolaWeb.Helpers.Currency.format_price(
              @product.min_price || 0,
              Map.get(@store, :currency, "GHS")
            )}
          </span>
          <span class="text-xs font-semibold text-[#C9925E] group-hover:underline">
            Add to bag →
          </span>
        </div>
      </div>
    </a>
    """
  end
end
