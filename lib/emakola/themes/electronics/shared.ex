defmodule Emakola.Themes.Electronics.Shared do
  @moduledoc """
  Shared components for Electronics — teal nav with sky-blue CTAs,
  monospace prices, "In Stock" pills, dark teal footer.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#134E4A") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#0EA5E9") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#F5EFE5") %>;
      }
      .electronics-body { font-family: 'Inter', sans-serif; color: #1F2937; background: var(--theme-bg); }
      .electronics-heading { font-family: 'Outfit', sans-serif; letter-spacing: -0.015em; }
      .electronics-mono { font-family: 'JetBrains Mono', monospace; }
      .electronics-card { background: #FFFFFF; border-radius: 16px; box-shadow: 0 1px 3px rgba(19,78,74,0.06); }
    </style>
    """
  end

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :on_dark, :boolean, default: false

  def electronics_nav(assigns) do
    ~H"""
    <header class={"sticky top-0 z-50 transition-colors " <> if(@on_dark, do: "bg-[#134E4A]/85 backdrop-blur-md", else: "bg-white/95 backdrop-blur-md border-b border-[#E5E7EB]")}>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 sm:h-20">
          <a href={"/s/#{@store.slug}"} class="flex items-center gap-3 min-w-0">
            <div class={"w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 " <> if(@on_dark, do: "bg-[#0EA5E9]", else: "bg-[#134E4A]")}>
              <span
                class={"material-symbols-outlined " <> if(@on_dark, do: "text-white", else: "text-[#0EA5E9]")}
                style="font-size: 22px;"
              >
                bolt
              </span>
            </div>
            <span class={"electronics-heading text-xl sm:text-2xl font-bold truncate " <> if(@on_dark, do: "text-white", else: "text-[#134E4A]")}>
              {@store.name}
            </span>
          </a>

          <%!-- Desktop search bar --%>
          <div class={"hidden md:flex items-center gap-3 flex-1 max-w-md mx-8 px-4 py-2.5 rounded-xl " <> if(@on_dark, do: "bg-white/10", else: "bg-[#F3F4F6]")}>
            <span
              class={"material-symbols-outlined " <> if(@on_dark, do: "text-white/60", else: "text-[#6B7280]")}
              style="font-size: 18px;"
            >
              search
            </span>
            <input
              type="text"
              placeholder="Search electronics..."
              class={"flex-1 bg-transparent text-sm focus:outline-none " <> if(@on_dark, do: "text-white placeholder:text-white/50", else: "text-[#1F2937] placeholder:text-[#6B7280]")}
            />
          </div>

          <div class="flex items-center gap-2 sm:gap-3">
            <a
              href={"/s/#{@store.slug}/account"}
              class={"hidden sm:flex w-11 h-11 rounded-full items-center justify-center transition-colors " <> if(@on_dark, do: "hover:bg-white/10", else: "hover:bg-[#F3F4F6]")}
              aria-label="Account"
            >
              <span
                class={"material-symbols-outlined " <> if(@on_dark, do: "text-white", else: "text-[#134E4A]")}
                style="font-size: 22px;"
              >
                person
              </span>
            </a>
            <a
              href={"/s/#{@store.slug}/cart"}
              class={"relative w-11 h-11 rounded-full flex items-center justify-center transition-colors " <> if(@on_dark, do: "hover:bg-white/10", else: "hover:bg-[#F3F4F6]")}
              aria-label={"Cart, #{@cart_count} items"}
            >
              <span
                class={"material-symbols-outlined " <> if(@on_dark, do: "text-white", else: "text-[#134E4A]")}
                style="font-size: 22px;"
              >
                shopping_bag
              </span>
              <span
                :if={@cart_count > 0}
                class="absolute -top-1 -right-1 min-w-[20px] h-5 px-1 rounded-full bg-[#0EA5E9] text-white text-[10px] font-bold flex items-center justify-center"
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

  attr :store, :map, required: true

  def electronics_footer(assigns) do
    ~H"""
    <footer class="bg-[#0A0F1F] text-white">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-10">
          <div class="md:col-span-2">
            <div class="flex items-center gap-3 mb-4">
              <div class="w-10 h-10 rounded-xl bg-[#0EA5E9] flex items-center justify-center">
                <span class="material-symbols-outlined text-white" style="font-size: 22px;">
                  bolt
                </span>
              </div>
              <span class="electronics-heading text-2xl font-bold">{@store.name}</span>
            </div>
            <p class="text-sm text-white/65 leading-relaxed max-w-md">
              {@store.description ||
                "Genuine electronics with 1-year warranty. Fast shipping across Ghana."}
            </p>
          </div>
          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#0EA5E9]">
              Shop
            </h4>
            <ul class="space-y-3 text-sm text-white/65">
              <li :for={cat <- ["Phones", "Audio", "Computers", "Wearables", "Accessories"]}>
                <a
                  href={"/s/#{@store.slug}/products"}
                  class="hover:text-white transition-colors"
                >
                  {cat}
                </a>
              </li>
            </ul>
          </div>
          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#0EA5E9]">
              Help
            </h4>
            <ul class="space-y-3 text-sm text-white/65">
              <li :for={item <- ["Warranty", "Returns", "Contact", "FAQ"]}>
                <a
                  href={"/s/#{@store.slug}/contact"}
                  class="hover:text-white transition-colors"
                >
                  {item}
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div class="border-t border-white/10 mt-12 pt-6 flex flex-col sm:flex-row justify-between items-center gap-3 text-xs text-white/50">
          <p>&copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.</p>
          <p class="electronics-mono">v1.0 · Ghana</p>
        </div>
      </div>
    </footer>
    """
  end

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

  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="electronics-card group block overflow-hidden hover:shadow-lg transition-all"
    >
      <div class="aspect-square bg-[#F3F4F6] overflow-hidden relative">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-contain p-4 group-hover:scale-105 transition-transform duration-500"
        />
        <div
          :if={!first_image(@product)}
          class="w-full h-full flex items-center justify-center"
        >
          <span class="material-symbols-outlined text-[#134E4A]/20" style="font-size: 64px;">
            devices
          </span>
        </div>
        <%!-- In Stock pill --%>
        <span class="absolute top-3 left-3 inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-[#10B981]/15 text-[#10B981] text-[10px] font-semibold">
          <span class="w-1.5 h-1.5 rounded-full bg-[#10B981]"></span> In Stock
        </span>
      </div>
      <div class="p-4 sm:p-5">
        <h3 class="electronics-heading text-sm sm:text-base font-semibold text-[#1F2937] line-clamp-2 mb-2 leading-snug min-h-[2.5rem]">
          {@product.title}
        </h3>
        <%!-- Color swatches placeholder --%>
        <div class="flex items-center gap-1 mb-3">
          <span class="w-3 h-3 rounded-full bg-[#1F2937] ring-1 ring-black/10"></span>
          <span class="w-3 h-3 rounded-full bg-[#0EA5E9] ring-1 ring-black/10"></span>
          <span class="w-3 h-3 rounded-full bg-[#134E4A] ring-1 ring-black/10"></span>
        </div>
        <div class="flex items-center justify-between">
          <span class="electronics-mono text-base font-bold text-[#134E4A]">
            {EmakolaWeb.Helpers.Currency.format_price(
              @product.min_price || 0,
              Map.get(@store, :currency, "GHS")
            )}
          </span>
          <span class="inline-flex items-center px-3 py-1.5 rounded-full bg-[#0EA5E9] text-white text-xs font-bold group-hover:bg-[#0284C7] transition-colors">
            Add
          </span>
        </div>
      </div>
    </a>
    """
  end
end
