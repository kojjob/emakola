defmodule Emakola.Themes.Savor.Shared do
  @moduledoc """
  Shared components for the Savor theme.

  Appetite-stimulating, communal, immediate design with:
  - Warm cream (#FFFBEB) background — feels like a printed menu
  - Tomato red (#DC2626) primary / olive (#15803D) accent — classic appetite palette
  - Anton condensed display headings + Lora warm serif body
  - Rounded "menu card" style with prominent food photography
  - Stock-per-day and delivery-ETA chips for restaurant immediacy
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── Theme Styles ──

  @doc """
  Injects a <style> block with CSS custom properties for the Savor theme.
  Call once near the top of any page that uses Savor components.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#DC2626" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#15803D" %>;
        --theme-highlight: <%= get_in(@theme, [:colors, :highlight]) || "#FEF3C7" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#FFFBEB" %>;
      }
    </style>
    """
  end

  # ── Savor Nav Bar ──

  @doc """
  Top navigation bar with red gradient accent stripe, store branding, and
  WhatsApp order button (the dominant CTA for restaurants in Ghana).
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def savor_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50">
      <div class="h-1 bg-gradient-to-r from-[var(--theme-primary,#DC2626)] via-[#B91C1C] to-[var(--theme-primary,#DC2626)]">
      </div>
      <div class="bg-[#FFFBEB] border-b border-[#FDE68A]/60 shadow-sm">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14 sm:h-16">
            <a href={"/s/#{@store.slug}"} class="flex items-center gap-3 min-w-0">
              <div class="w-10 h-10 rounded-full bg-gradient-to-br from-[var(--theme-primary,#DC2626)] to-[#7C2D12] flex items-center justify-center flex-shrink-0 shadow-md">
                <span class="text-sm font-bold text-white">
                  {String.first(@store.name)}
                </span>
              </div>
              <div class="min-w-0">
                <div
                  class="text-[0.9375rem] font-bold text-[#1C1917] truncate leading-tight tracking-wide"
                  style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
                >
                  {@store.name}
                </div>
                <div class="flex items-center gap-1 text-xs text-[#15803D] leading-tight">
                  <span class="w-1.5 h-1.5 rounded-full bg-[#15803D] animate-pulse flex-shrink-0">
                  </span>
                  <span>Open · Cooking now</span>
                </div>
              </div>
            </a>

            <div class="flex items-center gap-1">
              <a
                href={"/s/#{@store.slug}/products"}
                class="hidden sm:inline-flex p-2.5 rounded-xl hover:bg-[#FEF3C7] transition-colors"
                aria-label="Browse menu"
              >
                <svg
                  class="w-5 h-5 text-[#78350F]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.8"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M4 6h16M4 12h16M4 18h16"
                  />
                </svg>
              </a>
              <a
                :if={Map.get(@store, :whatsapp_number)}
                href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
                target="_blank"
                rel="noopener noreferrer"
                class="hidden sm:inline-flex items-center gap-1.5 px-3 py-2 rounded-full bg-[#25D366] text-white text-xs font-bold hover:bg-[#1FB855] transition-colors"
              >
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347" />
                </svg>
                Order
              </a>
              <a
                href={"/s/#{@store.slug}/cart"}
                class="relative p-2.5 rounded-xl hover:bg-[#FEF3C7] transition-colors"
                aria-label={"Bag, #{@cart_count} items"}
              >
                <svg
                  class="w-5 h-5 text-[#78350F]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.8"
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
                  class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[var(--theme-primary,#DC2626)] text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1"
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

  # ── Dish Card ──

  @doc """
  Menu-style dish card with prominent food photography, portion size, and
  optional spice level chip. Designed for the Savor product grid.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :portion, :string, default: nil
  attr :spice_level, :integer, default: nil

  def dish_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative rounded-2xl overflow-hidden mb-3 bg-[#FEF3C7]/60 shadow-md shadow-amber-100 group-hover:shadow-xl group-hover:shadow-amber-200/60 transition-all duration-300">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full aspect-[4/3] object-cover group-hover:scale-[1.06] transition-transform duration-500"
        />
        <div :if={!@image} class="w-full aspect-[4/3] flex items-center justify-center bg-[#FEF3C7]">
          <span class="material-symbols-outlined text-5xl text-[#D97706]">
            restaurant
          </span>
        </div>

        <div :if={@portion || @spice_level} class="absolute top-2 left-2 flex flex-wrap gap-1.5">
          <span
            :if={@portion}
            class="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-white/90 backdrop-blur-sm text-[11px] font-bold text-[#78350F]"
          >
            {@portion}
          </span>
          <span
            :if={@spice_level && @spice_level > 0}
            class={[
              "inline-flex items-center gap-1 px-2 py-1 rounded-full backdrop-blur-sm text-[11px] font-bold",
              spice_classes(@spice_level)
            ]}
          >
            {spice_label(@spice_level)}
          </span>
        </div>

        <div class="absolute bottom-0 left-0 right-0 p-3 bg-gradient-to-t from-[#1C1917]/85 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex justify-center">
          <span
            class="text-sm font-bold text-white tracking-wide"
            style="font-family: 'Anton', sans-serif;"
          >
            ADD TO BAG
          </span>
        </div>
      </div>
      <p
        class="text-base font-semibold text-[#1C1917] leading-tight mb-1 truncate"
        style="font-family: 'Lora', serif;"
      >
        {@product.title}
      </p>
      <p
        class="text-base font-bold text-[var(--theme-primary,#DC2626)] tabular-nums"
        style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
      >
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Restaurant-style footer: hours, location, payment methods (cash on delivery
  equal-weight with mobile money), social links.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[#1C1917] text-[#FEF3C7] mt-12">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
          <div>
            <p
              class="text-2xl font-bold text-white mb-3 tracking-wide"
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              {@store.name}
            </p>
            <p
              :if={@store.description}
              class="text-sm text-[#FEF3C7]/70 leading-relaxed"
              style="font-family: 'Lora', serif;"
            >
              {String.slice(@store.description, 0, 140)}
            </p>
          </div>

          <div>
            <p class="text-xs font-bold tracking-[0.2em] uppercase text-[var(--theme-accent,#15803D)] mb-3">
              Hours
            </p>
            <ul class="space-y-1 text-sm text-[#FEF3C7]/85" style="font-family: 'Lora', serif;">
              <li>Mon — Fri · 9:00 — 21:00</li>
              <li>Sat — Sun · 10:00 — 22:00</li>
            </ul>
          </div>

          <div>
            <p class="text-xs font-bold tracking-[0.2em] uppercase text-[var(--theme-accent,#15803D)] mb-3">
              Find us
            </p>
            <ul class="space-y-1 text-sm text-[#FEF3C7]/85" style="font-family: 'Lora', serif;">
              <li :if={Map.get(@store, :address)}>{@store.address}</li>
              <li :if={Map.get(@store, :city)}>{@store.city}, {Map.get(@store, :region)}</li>
              <li :if={Map.get(@store, :contact_phone)}>
                <a href={"tel:#{@store.contact_phone}"} class="hover:text-white transition-colors">
                  {@store.contact_phone}
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p class="text-xs font-bold tracking-[0.2em] uppercase text-[var(--theme-accent,#15803D)] mb-3">
              Pay how you like
            </p>
            <div class="flex flex-wrap gap-2">
              <span class="inline-flex items-center px-2.5 py-1 rounded-full bg-[#FFC107] text-[#1C1917] text-[11px] font-bold">
                MoMo
              </span>
              <span class="inline-flex items-center px-2.5 py-1 rounded-full bg-[#E60000] text-white text-[11px] font-bold">
                Vodafone
              </span>
              <span class="inline-flex items-center px-2.5 py-1 rounded-full bg-white text-[#1C1917] text-[11px] font-bold">
                Card
              </span>
              <span class="inline-flex items-center px-2.5 py-1 rounded-full bg-[#15803D] text-white text-[11px] font-bold">
                Cash on delivery
              </span>
            </div>
          </div>
        </div>

        <div class="mt-10 pt-6 border-t border-[#FEF3C7]/10 flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between text-xs text-[#FEF3C7]/50">
          <p style="font-family: 'Lora', serif;">
            © {Date.utc_today().year} {@store.name}. Cooked with love in Ghana.
          </p>
          <p style="font-family: 'Lora', serif;">Powered by Emakola</p>
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

  defp spice_classes(level) when level >= 3, do: "bg-[#DC2626] text-white"
  defp spice_classes(level) when level == 2, do: "bg-[#F59E0B] text-[#78350F]"
  defp spice_classes(_), do: "bg-white/90 text-[#78350F]"

  defp spice_label(1), do: "Mild"
  defp spice_label(2), do: "Medium"
  defp spice_label(3), do: "Hot"
  defp spice_label(level) when level > 3, do: "Extra hot"
  defp spice_label(_), do: ""

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end
end
