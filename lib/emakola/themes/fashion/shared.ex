defmodule Emakola.Themes.Fashion.Shared do
  @moduledoc """
  Shared components for Fashion — minimal nav with logo center
  (magazine masthead style), aubergine footer, lookbook product card.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#5B21B6") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#D97706") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FAF6EE") %>;
      }
      .fashion-body { font-family: 'Inter', sans-serif; color: #1C1917; background: var(--theme-bg); }
      .fashion-heading { font-family: 'Playfair Display', serif; letter-spacing: -0.005em; }
      .fashion-display { font-family: 'Playfair Display', serif; font-weight: 800; letter-spacing: -0.025em; }
      .fashion-card { background: #FFFFFF; border-radius: 8px; box-shadow: 0 1px 4px rgba(28,25,23,0.05); }
    </style>
    """
  end

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :on_dark, :boolean, default: false

  def fashion_nav(assigns) do
    ~H"""
    <header class={"sticky top-0 z-50 transition-colors " <> if(@on_dark, do: "bg-black/30 backdrop-blur-md", else: "bg-[#FAF6EE]/95 backdrop-blur-md border-b border-[#E7E5E4]")}>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-3 items-center h-16 sm:h-20">
          <%!-- Left: nav links --%>
          <nav class={"hidden md:flex items-center gap-7 text-xs font-medium uppercase tracking-[0.18em] " <> if(@on_dark, do: "text-white/85", else: "text-[#1C1917]/80")}>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-[#D97706] transition-colors"
            >
              Shop
            </a>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-[#D97706] transition-colors"
            >
              Lookbook
            </a>
            <a href={store_path(@store.slug, "/blog")} class="hover:text-[#D97706] transition-colors">
              Journal
            </a>
          </nav>
          <div class="md:hidden"></div>

          <%!-- Center: logo (magazine masthead) --%>
          <a
            href={store_path(@store.slug, "/")}
            class={"text-center fashion-display text-xl sm:text-2xl tracking-[0.25em] uppercase truncate " <> if(@on_dark, do: "text-white", else: "text-[#1C1917]")}
          >
            {@store.name}
          </a>

          <%!-- Right: cart + cta --%>
          <div class="flex items-center justify-end gap-2 sm:gap-3">
            <a
              href={store_path(@store.slug, "/account")}
              class={"hidden sm:flex w-11 h-11 rounded-full items-center justify-center transition-colors " <> if(@on_dark, do: "hover:bg-white/10", else: "hover:bg-[#E7E5E4]/50")}
              aria-label="Account"
            >
              <span
                class={"material-symbols-outlined " <> if(@on_dark, do: "text-white", else: "text-[#1C1917]")}
                style="font-size: 22px;"
              >
                person
              </span>
            </a>
            <a
              href={store_path(@store.slug, "/cart")}
              class={"relative w-11 h-11 rounded-full flex items-center justify-center transition-colors " <> if(@on_dark, do: "hover:bg-white/10", else: "hover:bg-[#E7E5E4]/50")}
              aria-label={"Cart, #{@cart_count} items"}
            >
              <span
                class={"material-symbols-outlined " <> if(@on_dark, do: "text-white", else: "text-[#1C1917]")}
                style="font-size: 22px;"
              >
                shopping_bag
              </span>
              <span
                :if={@cart_count > 0}
                class="absolute -top-1 -right-1 min-w-[20px] h-5 px-1 rounded-full bg-[#D97706] text-white text-[10px] font-bold flex items-center justify-center"
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

  def fashion_footer(assigns) do
    ~H"""
    <footer class="bg-[#5B21B6] text-[#FAF6EE]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-20">
        <div class="text-center mb-12">
          <p class="fashion-display text-3xl sm:text-4xl tracking-[0.25em] uppercase">
            {@store.name}
          </p>
          <p class="text-xs tracking-[0.18em] uppercase text-[#FAF6EE]/60 mt-3">
            Made in Ghana
          </p>
        </div>

        <div class="grid grid-cols-2 md:grid-cols-4 gap-8 max-w-3xl mx-auto">
          <div :for={col <- footer_columns()} class="text-center md:text-left">
            <h4 class="text-[11px] font-semibold uppercase tracking-[0.18em] mb-4 text-[#D97706]">
              {col.title}
            </h4>
            <ul class="space-y-2 text-sm text-[#FAF6EE]/75">
              <li :for={link <- col.links}>
                <a
                  href={store_path(@store.slug, "#{link.path}")}
                  class="hover:text-white transition-colors"
                >
                  {link.label}
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="border-t border-[#FAF6EE]/15 mt-14 pt-6 flex flex-col sm:flex-row items-center justify-between gap-3 text-[11px] text-[#FAF6EE]/50 uppercase tracking-wider">
          <p>&copy; {DateTime.utc_now().year} {@store.name}</p>
          <p>Volume IV · {DateTime.utc_now().year}</p>
        </div>
      </div>
    </footer>
    """
  end

  defp footer_columns do
    [
      %{
        title: "Shop",
        links: [
          %{label: "All", path: "/products"},
          %{label: "Ankara", path: "/products"},
          %{label: "Kente", path: "/products"},
          %{label: "Accessories", path: "/products"}
        ]
      },
      %{
        title: "About",
        links: [
          %{label: "Our story", path: "/about"},
          %{label: "Tailors", path: "/about"},
          %{label: "Journal", path: "/blog"}
        ]
      },
      %{
        title: "Help",
        links: [
          %{label: "Contact", path: "/contact"},
          %{label: "Returns", path: "/contact"},
          %{label: "Sizing", path: "/contact"}
        ]
      },
      %{
        title: "Follow",
        links: [
          %{label: "Instagram", path: ""},
          %{label: "TikTok", path: ""},
          %{label: "Pinterest", path: ""}
        ]
      }
    ]
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
      class="group block"
    >
      <div class="relative aspect-[3/4] bg-white overflow-hidden mb-3">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
        />
        <div
          :if={!first_image(@product)}
          class="w-full h-full flex items-center justify-center bg-gradient-to-br from-[#FAF6EE] to-[#E7E5E4]"
        >
          <span class="material-symbols-outlined text-[#5B21B6]/30" style="font-size: 56px;">
            checkroom
          </span>
        </div>
        <%!-- Gold "New" pill --%>
        <span class="absolute top-3 left-3 px-3 py-1 rounded-full bg-[#D97706] text-white text-[10px] font-bold uppercase tracking-wider">
          New
        </span>
      </div>
      <h3 class="fashion-heading text-base sm:text-lg font-semibold text-[#1C1917] mb-1 line-clamp-2 leading-snug min-h-[2.5rem]">
        {@product.title}
      </h3>
      <p class="text-sm text-[#5B21B6] font-bold">
        {EmakolaWeb.Helpers.Currency.format_price(
          @product.min_price || 0,
          Map.get(@store, :currency, "GHS")
        )}
      </p>
    </a>
    """
  end
end
