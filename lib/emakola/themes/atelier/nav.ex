defmodule Emakola.Themes.Atelier.Nav do
  @moduledoc """
  Navigation bar component family for the Atelier artisan craft theme.

  Includes the main `navbar/1` function component plus the small
  `show_search/0` and `hide_search/0` JS helpers used by the search
  overlay it embeds.

  Extracted from `Emakola.Themes.Atelier.Shared` (commit 90b5327
  extracted the footer; this commit extracts navigation). The shared
  module retains a `defdelegate` so callers don't need to change.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Phoenix.LiveView.JS

  # ── Navigation ──

  @doc """
  Atelier white navigation bar (Stitch design reference).

  - White background, sticky top, subtle bottom border
  - Left: Store name in bold accent color
  - Center: Nav links with active underline in theme primary
  - Right: Search pill, Cart icon (with badge), Account icon
  - Mobile: center links and search text hidden, icon-only
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :transparent, :boolean, default: false
  attr :active_path, :string, default: nil
  attr :search_placeholder, :string, default: nil

  def navbar(assigns) do
    store_name = Map.get(assigns.store, :name, "products")

    search_text =
      assigns[:search_placeholder] ||
        "Search #{store_name}..."

    assigns = assign(assigns, :search_text, search_text)

    ~H"""
    <nav
      id="atelier-navbar"
      class={"sticky top-0 left-0 right-0 z-50 bg-white border-b border-gray-100" <>
        if(@transparent, do: " atelier-nav-transparent", else: "")}
      phx-hook={if(@transparent, do: "ScrollGlass", else: nil)}
      data-scroll-threshold="60"
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 sm:h-20">
          <%!-- Left: Store logo or name --%>
          <a
            href={"/s/#{@store.slug}"}
            class="cursor-pointer transition-opacity duration-200 hover:opacity-80 min-h-[44px] flex items-center gap-2.5"
          >
            <.optimized_image
              :if={Map.get(@store, :logo_url) && Map.get(@store, :logo_url) != ""}
              src={@store.logo_url}
              alt={@store.name}
              priority={:high}
              class="h-8 sm:h-10 w-auto object-contain"
            />
            <span
              class="atelier-nav-brand text-xl sm:text-2xl font-black tracking-tight"
              style="color: var(--theme-accent);"
            >
              {@store.name}
            </span>
          </a>

          <%!-- Center: Nav links (Desktop only — hidden below xl for long category names) --%>
          <div class="hidden xl:flex items-center gap-5">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "atelier-nav-link relative text-sm font-medium cursor-pointer transition-colors duration-200 hover:text-gray-900 min-h-[44px] flex items-center whitespace-nowrap",
                if(@active_path in ["/", "/products", nil] and @active_path != nil,
                  do: "text-gray-900",
                  else: "text-gray-600"
                )
              ]}
            >
              Shop
              <span
                :if={@active_path in ["/", "/products"]}
                class="absolute bottom-0 left-0 right-0 h-0.5"
                style="background: var(--theme-primary);"
              />
            </a>
            <a
              :for={category <- Enum.take(@categories, 3)}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class={[
                "atelier-nav-link relative text-sm font-medium cursor-pointer transition-colors duration-200 hover:text-gray-900 min-h-[44px] flex items-center whitespace-nowrap max-w-[160px] truncate",
                if(@active_path == "/category/#{category.slug}",
                  do: "text-gray-900 font-semibold",
                  else: "text-gray-600"
                )
              ]}
              title={category.name}
            >
              {category.name}
              <span
                :if={@active_path == "/category/#{category.slug}"}
                class="absolute bottom-0 left-0 right-0 h-0.5"
                style="background: var(--theme-primary);"
              />
            </a>
            <a
              href={"/s/#{@store.slug}/blog"}
              class="atelier-nav-link relative text-sm font-medium cursor-pointer transition-colors duration-200 hover:text-gray-900 min-h-[44px] flex items-center text-gray-600 whitespace-nowrap"
            >
              Journal
            </a>
          </div>

          <%!-- Right: Search + Icons + Mobile Menu --%>
          <div class="flex items-center gap-3 sm:gap-4">
            <%!-- Search Bar (Desktop pill) --%>
            <button
              type="button"
              phx-click={show_search()}
              class="atelier-nav-search hidden md:flex items-center gap-2 bg-gray-100 rounded-full px-4 py-2.5 text-sm text-gray-500 cursor-pointer transition-colors duration-200 hover:bg-gray-200 min-w-[220px] min-h-[44px]"
            >
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="flex-shrink-0"
              >
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <span class="truncate">{@search_text}</span>
            </button>

            <%!-- Search Icon (Mobile) --%>
            <button
              type="button"
              phx-click={show_search()}
              class="atelier-nav-icon md:hidden flex items-center justify-center w-11 h-11 text-gray-700 cursor-pointer transition-colors duration-200 hover:text-gray-900 rounded-full hover:bg-gray-100"
              aria-label="Search"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
            </button>

            <%!-- Cart --%>
            <a
              href={"/s/#{@store.slug}/cart"}
              class="atelier-nav-icon relative flex items-center justify-center w-11 h-11 text-gray-700 cursor-pointer transition-colors duration-200 hover:text-gray-900 rounded-full hover:bg-gray-100"
              aria-label={"Shopping cart, #{@cart_count} items"}
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" />
                <line x1="3" y1="6" x2="21" y2="6" />
                <path d="M16 10a4 4 0 01-8 0" />
              </svg>
              <span
                :if={@cart_count > 0}
                class="absolute top-0.5 right-0.5 w-5 h-5 text-[10px] font-bold rounded-full flex items-center justify-center text-white"
                style="background: var(--theme-primary);"
              >
                {@cart_count}
              </span>
            </a>

            <%!-- Account (Desktop) --%>
            <a
              href={"/s/#{@store.slug}/account"}
              class="atelier-nav-icon hidden sm:flex items-center justify-center w-11 h-11 text-gray-700 cursor-pointer transition-colors duration-200 hover:text-gray-900 rounded-full hover:bg-gray-100"
              aria-label="Account"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" /><circle cx="12" cy="7" r="4" />
              </svg>
            </a>

            <%!-- Hamburger Menu (Mobile) --%>
            <button
              type="button"
              phx-click={show_mobile_menu()}
              class="atelier-nav-icon xl:hidden flex items-center justify-center w-11 h-11 text-gray-700 cursor-pointer transition-colors duration-200 hover:text-gray-900 rounded-full hover:bg-gray-100"
              aria-label="Open menu"
              aria-controls="atelier-mobile-drawer"
            >
              <svg
                width="22"
                height="22"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              >
                <line x1="3" y1="6" x2="21" y2="6" /><line x1="3" y1="12" x2="21" y2="12" /><line
                  x1="3"
                  y1="18"
                  x2="21"
                  y2="18"
                />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <%!-- Mobile Drawer (JS-driven; survives LV diffs unlike CSS-checkbox) --%>
      <%!-- Backdrop --%>
      <div
        id="atelier-mobile-backdrop"
        phx-click={hide_mobile_menu()}
        class="hidden fixed inset-0 bg-black/40 z-40"
        aria-hidden="true"
      />
      <%!-- Drawer panel --%>
      <div
        id="atelier-mobile-drawer"
        phx-click-away={hide_mobile_menu()}
        class="fixed top-0 right-0 h-full w-80 max-w-[85vw] bg-white z-50 shadow-2xl overflow-y-auto translate-x-full transition-transform duration-300 ease-out"
        role="dialog"
        aria-modal="true"
        aria-label="Mobile menu"
      >
        <div class="p-6">
          <%!-- Close button --%>
          <div class="flex items-center justify-between mb-8">
            <a
              href={"/s/#{@store.slug}"}
              class="text-lg font-black tracking-tight"
              style="color: var(--theme-accent);"
            >
              {@store.name}
            </a>
            <button
              type="button"
              phx-click={hide_mobile_menu()}
              class="flex items-center justify-center w-10 h-10 text-gray-500 cursor-pointer hover:text-gray-900 rounded-full hover:bg-gray-100"
              aria-label="Close menu"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              >
                <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>

          <%!-- Search --%>
          <button
            type="button"
            phx-click={show_search()}
            class="w-full flex items-center gap-3 bg-gray-100 rounded-lg px-4 py-3 text-sm text-gray-500 mb-8 min-h-[48px] cursor-pointer"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            {@search_text}
          </button>

          <%!-- Nav Links --%>
          <nav class="space-y-1 mb-8">
            <a
              href={"/s/#{@store.slug}/products"}
              class="block px-3 py-3 text-sm font-medium text-gray-900 rounded-lg hover:bg-gray-50 min-h-[44px] flex items-center"
            >
              Shop All
            </a>
            <a
              href={"/s/#{@store.slug}/collections"}
              class="block px-3 py-3 text-sm font-medium text-gray-600 rounded-lg hover:bg-gray-50 min-h-[44px] flex items-center"
            >
              Collections
            </a>
            <a
              :for={category <- @categories}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class="block px-3 py-3 text-sm font-medium text-gray-600 rounded-lg hover:bg-gray-50 min-h-[44px] flex items-center"
            >
              {category.name}
            </a>
          </nav>

          <div class="border-t border-gray-100 pt-6 space-y-1">
            <a
              href={"/s/#{@store.slug}/about"}
              class="block px-3 py-3 text-sm text-gray-600 rounded-lg hover:bg-gray-50 min-h-[44px] flex items-center"
            >
              About Us
            </a>
            <a
              href={"/s/#{@store.slug}/blog"}
              class="block px-3 py-3 text-sm text-gray-600 rounded-lg hover:bg-gray-50 min-h-[44px] flex items-center"
            >
              Blog
            </a>
            <a
              href={"/s/#{@store.slug}/recipes"}
              class="block px-3 py-3 text-sm text-gray-600 rounded-lg hover:bg-gray-50 min-h-[44px] flex items-center"
            >
              Recipes
            </a>
            <a
              href={"/s/#{@store.slug}/account"}
              class="block px-3 py-3 text-sm text-gray-600 rounded-lg hover:bg-gray-50 min-h-[44px] flex items-center gap-2"
            >
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" /><circle cx="12" cy="7" r="4" />
              </svg>
              Account
            </a>
            <a
              :if={Map.get(@store, :whatsapp_number)}
              href={"https://wa.me/#{@store.whatsapp_number}"}
              target="_blank"
              rel="noopener noreferrer"
              class="block px-3 py-3 text-sm text-gray-600 rounded-lg hover:bg-gray-50 min-h-[44px] flex items-center gap-2"
            >
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="currentColor"
                style="color: #25D366;"
              >
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                <path d="M12 0C5.373 0 0 5.373 0 12c0 2.625.846 5.059 2.284 7.034L.789 23.492a.5.5 0 00.613.613l4.458-1.495A11.952 11.952 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-2.24 0-4.31-.726-5.99-1.956l-.418-.312-2.65.888.888-2.65-.312-.418A9.935 9.935 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z" />
              </svg>
              WhatsApp
            </a>
          </div>
        </div>
      </div>
    </nav>

    <%!-- Atelier-nav search overlay — distinct from the layout's
         SearchComponents.search_overlay (which uses #search-overlay /
         #search-input). Different IDs prevent LiveView's duplicate-id
         strict mode from raising. --%>
    <div
      id="atelier-nav-search-overlay"
      class="hidden fixed inset-0 z-[60] bg-black/50"
      phx-click={hide_search()}
    >
      <div
        class="mx-auto mt-20 w-full max-w-2xl px-4"
        phx-click-away={hide_search()}
      >
        <form
          action={"/s/#{@store.slug}/products"}
          method="get"
          class="bg-white rounded-xl shadow-2xl overflow-hidden"
          phx-click={JS.dispatch("click", to: "#atelier-nav-search-overlay")}
          onclick="event.stopPropagation()"
        >
          <div class="flex items-center gap-3 px-5 py-4">
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="flex-shrink-0 text-gray-400"
            >
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <%!-- Decorative input only — actual search lives in the
                 layout's SearchComponents.search_overlay (#search-input).
                 A unique id avoids LiveView's duplicate-id strict mode. --%>
            <input
              id="atelier-nav-search-decorative"
              type="text"
              name="q"
              placeholder="Search products..."
              class="flex-1 text-base text-gray-900 placeholder-gray-400 border-0 outline-none focus:ring-0 bg-transparent"
              autocomplete="off"
            />
            <button
              type="button"
              phx-click={hide_search()}
              class="text-gray-400 hover:text-gray-600 p-1"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>
          <div class="border-t border-gray-100 px-5 py-3 bg-gray-50 text-xs text-gray-400">
            Press Enter to search
          </div>
        </form>
      </div>
    </div>
    """
  end

  @doc """
  JS command to show the search overlay and focus the input.
  """
  def show_search do
    JS.show(
      to: "#atelier-nav-search-overlay",
      transition: {"ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> JS.focus(to: "#atelier-nav-search-decorative")
  end

  @doc """
  JS command to hide the search overlay.
  """
  def hide_search do
    JS.hide(
      to: "#atelier-nav-search-overlay",
      transition: {"ease-in duration-150", "opacity-100", "opacity-0"}
    )
  end

  @doc """
  JS command to open the mobile menu drawer.

  Shows the backdrop, slides the drawer in from the right, and locks
  body scroll. Survives LV diffs because it manipulates classes via
  JS commands, not server state.
  """
  def show_mobile_menu do
    JS.remove_class("hidden", to: "#atelier-mobile-backdrop")
    |> JS.remove_class("translate-x-full", to: "#atelier-mobile-drawer")
    |> JS.add_class("overflow-hidden", to: "body")
  end

  @doc """
  JS command to close the mobile menu drawer.
  """
  def hide_mobile_menu do
    JS.add_class("hidden", to: "#atelier-mobile-backdrop")
    |> JS.add_class("translate-x-full", to: "#atelier-mobile-drawer")
    |> JS.remove_class("overflow-hidden", to: "body")
  end
end
