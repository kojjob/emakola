defmodule Emakola.Themes.Heritage.Shared do
  @moduledoc """
  Shared components for the Heritage theme: theme_styles, heritage_nav
  (centered cream nav with burgundy CTA), heritage_footer (deep burgundy),
  product_card, image helpers.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#7A1F1F" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#D4A843" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#FAF6EC" %>;
        --theme-on-dark: <%= get_in(@theme, [:colors, :on_dark]) || "#F5EFE0" %>;
      }
      .heritage-body { font-family: 'Inter', sans-serif; color: #3D2817; background: var(--theme-bg); }
      .heritage-heading { font-family: 'Playfair Display', serif; letter-spacing: -0.01em; }
      .heritage-italic { font-family: 'Playfair Display', serif; font-style: italic; font-weight: 400; }
      .heritage-card { background: #FFFFFF; border-radius: 14px; box-shadow: 0 1px 3px rgba(122,31,31,0.06); }
    </style>
    """
  end

  # ── Heritage Navbar ──

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :on_dark, :boolean, default: false

  def heritage_nav(assigns) do
    ~H"""
    <header class={[
      "sticky top-0 z-50",
      if(@on_dark,
        do: "bg-[#7A1F1F]/95 backdrop-blur-md",
        else: "bg-[#FAF6EC]/95 backdrop-blur-md border-b border-[#E8DBC2]"
      )
    ]}>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 sm:h-20">
          <%!-- Brand wordmark --%>
          <a href={"/s/#{@store.slug}"} class="flex items-center gap-2 min-w-0">
            <span class={[
              "heritage-heading text-xl sm:text-2xl font-bold",
              if(@on_dark, do: "text-[#F5EFE0]", else: "text-[#7A1F1F]")
            ]}>
              {@store.name}
            </span>
          </a>

          <%!-- Center nav links --%>
          <nav class="hidden md:flex items-center gap-7">
            <a
              :for={
                {label, path, active?} <- [
                  {"Marketplace", "/products", true},
                  {"Artisans", "/about", false},
                  {"Heritage", "/blog", false},
                  {"Collections", "/products", false}
                ]
              }
              href={"/s/#{@store.slug}#{path}"}
              class={[
                "text-sm font-medium transition-colors",
                cond do
                  @on_dark && active? ->
                    "text-[#D4A843]"

                  @on_dark ->
                    "text-[#F5EFE0]/80 hover:text-[#F5EFE0]"

                  active? ->
                    "text-[#7A1F1F] underline underline-offset-8 decoration-2 decoration-[#D4A843]"

                  true ->
                    "text-[#3D2817] hover:text-[#7A1F1F]"
                end
              ]}
            >
              {label}
            </a>
          </nav>

          <%!-- Right cluster: search + cart + account --%>
          <div class="flex items-center gap-2 sm:gap-3">
            <form
              action={"/s/#{@store.slug}/products"}
              method="get"
              class="hidden lg:flex items-center relative"
            >
              <input
                type="search"
                name="q"
                placeholder="Search shops..."
                class={[
                  "pl-10 pr-4 py-2 rounded-full text-sm w-56 focus:outline-none focus:ring-2",
                  if(@on_dark,
                    do:
                      "bg-white/10 border border-white/20 text-[#F5EFE0] placeholder:text-[#F5EFE0]/50 focus:ring-[#D4A843]/50",
                    else:
                      "bg-white border border-[#E8DBC2] text-[#3D2817] placeholder:text-[#7A1F1F]/40 focus:ring-[#D4A843]"
                  )
                ]}
              />
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class={[
                  "absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4",
                  if(@on_dark, do: "text-[#F5EFE0]/60", else: "text-[#7A1F1F]/50")
                ]}
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <circle cx="11" cy="11" r="7" />
                <path d="m21 21-4.3-4.3" />
              </svg>
            </form>

            <a
              href={"/s/#{@store.slug}/cart"}
              class={[
                "relative w-10 h-10 rounded-full flex items-center justify-center transition-colors",
                if(@on_dark, do: "hover:bg-white/10", else: "hover:bg-[#E8DBC2]")
              ]}
              aria-label={"Cart, #{@cart_count} items"}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class={[
                  "w-5 h-5",
                  if(@on_dark, do: "text-[#F5EFE0]", else: "text-[#7A1F1F]")
                ]}
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z" />
                <path d="M3 6h18M16 10a4 4 0 0 1-8 0" />
              </svg>
              <span
                :if={@cart_count > 0}
                class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-[#D4A843] text-[#3D2817] text-[10px] font-bold flex items-center justify-center"
              >
                {@cart_count}
              </span>
            </a>

            <a
              href={"/s/#{@store.slug}/account"}
              class={[
                "w-10 h-10 rounded-full flex items-center justify-center transition-colors",
                if(@on_dark, do: "hover:bg-white/10", else: "hover:bg-[#E8DBC2]")
              ]}
              aria-label="Account"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class={[
                  "w-5 h-5",
                  if(@on_dark, do: "text-[#F5EFE0]", else: "text-[#7A1F1F]")
                ]}
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <circle cx="12" cy="8" r="4" />
                <path d="M4 21a8 8 0 0 1 16 0" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Heritage Footer ──

  attr :store, :map, required: true

  def heritage_footer(assigns) do
    ~H"""
    <footer class="bg-[#7A1F1F] text-[#F5EFE0]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-16">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-10">
          <div class="md:col-span-2">
            <span class="heritage-heading text-3xl font-bold">{@store.name}</span>
            <p class="text-sm text-[#F5EFE0]/75 leading-relaxed mt-4 max-w-md">
              {@store.description ||
                "A marketplace for Africa's finest artisans — heritage crafts, fair trade, and stories carried in every stitch."}
            </p>
          </div>

          <div>
            <h4 class="text-xs font-bold uppercase tracking-[0.2em] mb-4 text-[#D4A843]">
              Marketplace
            </h4>
            <ul class="space-y-3 text-sm text-[#F5EFE0]/75">
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  All artisans
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  Collections
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/blog"} class="hover:text-white transition-colors">
                  Stories
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="text-xs font-bold uppercase tracking-[0.2em] mb-4 text-[#D4A843]">
              Heritage
            </h4>
            <ul class="space-y-3 text-sm text-[#F5EFE0]/75">
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
                <a href={"/s/#{@store.slug}/about"} class="hover:text-white transition-colors">
                  Fair trade
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="border-t border-[#F5EFE0]/15 mt-12 pt-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-[#F5EFE0]/55">
          <p>&copy; {DateTime.utc_now().year} {@store.name}. Crafted in West Africa.</p>
          <p class="heritage-italic">Stories woven into every thread.</p>
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
      class="heritage-card group block overflow-hidden hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300"
    >
      <div class="aspect-[4/5] bg-[#F5EFE0] flex items-center justify-center overflow-hidden relative">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <svg
          :if={!first_image(@product)}
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          class="w-16 h-16 text-[#D4A843]/40"
          fill="currentColor"
          aria-hidden="true"
        >
          <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
        </svg>

        <%!-- "BEST SELLER" gold badge (renders if featured-rank ≤ 3) --%>
        <span
          :if={
            Map.get(@product, :featured_rank) &&
              @product.featured_rank <= 3
          }
          class="absolute top-3 right-3 inline-flex items-center justify-center w-14 h-14 rounded-full bg-[#D4A843] text-[#3D2817] text-[9px] font-black uppercase tracking-tight text-center leading-tight shadow-md"
        >
          Best<br />Seller
        </span>
      </div>
      <div class="p-5">
        <h3 class="heritage-heading text-lg font-semibold text-[#3D2817] line-clamp-2 mb-2 leading-snug">
          {@product.title}
        </h3>
        <div class="flex items-center justify-between gap-3 mt-3">
          <span class="text-base font-bold text-[#7A1F1F]">
            {EmakolaWeb.Helpers.Currency.format_price(
              @product.min_price || 0,
              Map.get(@store, :currency, "GHS")
            )}
          </span>
          <span class="inline-flex items-center gap-1 text-xs font-bold uppercase tracking-wider text-[#D4A843] group-hover:gap-1.5 transition-all">
            Visit
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              class="w-3 h-3"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M5 12h14M13 5l7 7-7 7" />
            </svg>
          </span>
        </div>
      </div>
    </a>
    """
  end
end
