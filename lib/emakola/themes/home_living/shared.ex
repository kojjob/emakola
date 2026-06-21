defmodule Emakola.Themes.HomeLiving.Shared do
  @moduledoc """
  Shared components for Home Living — Furniora-style charcoal nav with
  lime-green active state, dark footer, modern sans typography.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#1F2937") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#84CC16") %>;
        --theme-secondary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :secondary]), "#C2410C") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FAF7F2") %>;
      }
      .home-living-body { font-family: 'Inter', sans-serif; color: #1F2937; background: var(--theme-bg); }
      .home-living-heading { font-family: 'DM Sans', sans-serif; letter-spacing: -0.02em; }
      .home-living-display { font-family: 'DM Sans', sans-serif; font-weight: 800; letter-spacing: -0.025em; text-transform: uppercase; line-height: 1.0; }
      .home-living-card { background: #FFFFFF; border-radius: 18px; box-shadow: 0 1px 4px rgba(31,41,55,0.06); }
    </style>
    """
  end

  @doc """
  Charcoal nav with lime-green active link state (Furniora-inspired).
  Uses `:on_dark` to render against the dark hero where it's transparent.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :on_dark, :boolean, default: false
  attr :active_path, :string, default: ""

  def home_living_nav(assigns) do
    ~H"""
    <header class={"sticky top-0 z-50 transition-colors " <> if(@on_dark, do: "bg-[#1F2937]/85 backdrop-blur-md", else: "bg-white/95 backdrop-blur-md border-b border-[#E5E7EB]")}>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 sm:h-20">
          <a href={store_path(@store.slug, "/")} class="flex items-center gap-3 min-w-0">
            <span class={"home-living-heading text-xl sm:text-2xl font-bold truncate " <> if(@on_dark, do: "text-white", else: "text-[#1F2937]")}>
              {@store.name}
            </span>
          </a>

          <nav class={"hidden md:flex items-center gap-7 text-sm font-medium " <> if(@on_dark, do: "text-white/80", else: "text-[#1F2937]/80")}>
            <%= for {label, path} <- [{"Home", "/"}, {"Shop", "/products"}, {"Rooms", "/rooms"}, {"Blog", "/blog"}, {"Contact", "/contact"}] do %>
              <a
                href={store_path(@store.slug, "#{path}")}
                class={"transition-colors " <> if(@active_path == path, do: "text-[#84CC16] font-semibold", else: "hover:text-[#84CC16]")}
              >
                {label}
              </a>
            <% end %>
          </nav>

          <div class="flex items-center gap-2 sm:gap-3">
            <a
              href={store_path(@store.slug, "/cart")}
              class={"relative w-11 h-11 rounded-full flex items-center justify-center transition-colors " <> if(@on_dark, do: "hover:bg-white/10", else: "hover:bg-[#F3F4F6]")}
              aria-label={"Cart, #{@cart_count} items"}
            >
              <span
                class={"material-symbols-outlined " <> if(@on_dark, do: "text-white", else: "text-[#1F2937]")}
                style="font-size: 22px;"
              >
                shopping_bag
              </span>
              <span
                :if={@cart_count > 0}
                class="absolute -top-1 -right-1 min-w-[20px] h-5 px-1 rounded-full bg-[#84CC16] text-[#1F2937] text-[10px] font-bold flex items-center justify-center"
              >
                {@cart_count}
              </span>
            </a>
            <a
              href={store_path(@store.slug, "/products")}
              class={"hidden sm:inline-flex items-center px-5 py-2.5 rounded-full text-sm font-semibold transition-colors min-h-[44px] " <> if(@on_dark, do: "bg-white text-[#1F2937] hover:bg-[#84CC16]", else: "bg-[#1F2937] text-white hover:bg-[#374151]")}
            >
              Shop Now
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  Charcoal footer with lime accents.
  """
  attr :store, :map, required: true

  def home_living_footer(assigns) do
    ~H"""
    <footer class="bg-[#1F2937] text-white">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-10">
          <div class="md:col-span-2">
            <span class="home-living-heading text-2xl font-bold">{@store.name}</span>
            <p class="text-sm text-white/65 leading-relaxed mt-4 max-w-md">
              {@store.description ||
                "Modern furniture and home goods, made for the way you live."}
            </p>
            <div class="flex items-center gap-3 mt-6">
              <div class="w-9 h-9 rounded-full bg-white/10 flex items-center justify-center">
                <span class="material-symbols-outlined text-white" style="font-size: 18px;">
                  mail
                </span>
              </div>
              <div class="w-9 h-9 rounded-full bg-white/10 flex items-center justify-center">
                <span class="material-symbols-outlined text-white" style="font-size: 18px;">
                  share
                </span>
              </div>
            </div>
          </div>

          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#84CC16]">
              Shop
            </h4>
            <ul class="space-y-3 text-sm text-white/65">
              <li :for={room <- ["Living", "Bedroom", "Kitchen", "Bathroom", "Lighting"]}>
                <a
                  href={store_path(@store.slug, "/products")}
                  class="hover:text-white transition-colors"
                >
                  {room}
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="text-sm font-semibold uppercase tracking-wider mb-4 text-[#84CC16]">
              Help
            </h4>
            <ul class="space-y-3 text-sm text-white/65">
              <li>
                <a href={store_path(@store.slug, "/about")} class="hover:text-white transition-colors">
                  Our story
                </a>
              </li>
              <li>
                <a
                  href={store_path(@store.slug, "/contact")}
                  class="hover:text-white transition-colors"
                >
                  Contact
                </a>
              </li>
              <li>
                <a href={store_path(@store.slug, "/blog")} class="hover:text-white transition-colors">
                  Journal
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="border-t border-white/10 mt-12 pt-6 flex flex-col sm:flex-row justify-between items-center gap-3 text-xs text-white/50">
          <p>&copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.</p>
          <p>Designed for living</p>
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
      href={store_path(@store.slug, "/products/#{@product.slug}")}
      class="home-living-card group block overflow-hidden hover:shadow-lg transition-all"
    >
      <div class="aspect-square bg-[#F3F4F6] overflow-hidden relative">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <div
          :if={!first_image(@product)}
          class="w-full h-full flex items-center justify-center"
        >
          <span class="material-symbols-outlined text-[#1F2937]/20" style="font-size: 64px;">
            chair
          </span>
        </div>
        <%!-- Sale pill --%>
        <span class="absolute top-3 left-3 px-2.5 py-1 rounded-full bg-[#84CC16] text-[#1F2937] text-[10px] font-bold uppercase tracking-wider">
          New
        </span>
      </div>
      <div class="p-4 sm:p-5">
        <h3 class="home-living-heading text-base sm:text-lg font-semibold text-[#1F2937] line-clamp-2 mb-2 leading-snug min-h-[2.75rem]">
          {@product.title}
        </h3>
        <div class="flex items-center justify-between mt-2">
          <span class="text-base font-bold text-[#1F2937]">
            {EmakolaWeb.Helpers.Currency.format_price(
              @product.min_price || 0,
              Map.get(@store, :currency, "GHS")
            )}
          </span>
          <span class="w-9 h-9 rounded-full bg-[#1F2937] text-white flex items-center justify-center group-hover:bg-[#84CC16] group-hover:text-[#1F2937] transition-colors">
            <span class="material-symbols-outlined" style="font-size: 18px;">add</span>
          </span>
        </div>
      </div>
    </a>
    """
  end
end
