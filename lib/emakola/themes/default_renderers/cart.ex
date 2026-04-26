defmodule Emakola.Themes.DefaultRenderers.Cart do
  @moduledoc """
  Default render for the storefront cart page.

  Used by `EmakolaWeb.Storefront.CartLive` when no theme overrides
  `:render_cart`. Extracted from the LiveView's inline `render_default/1`
  so themes can opt out of any one page (or all pages) without copying
  300+ lines of markup per fork.

  This is the **first** of 11 default renderers planned for Phase 1 of
  the white-label design system (see
  `docs/PLAN-design-system-delta-2026-04-26.md`). Pattern documented at
  end of file.

  ## Pattern

      # In the LiveView's render/1:
      def render(assigns) do
        case Emakola.Themes.ThemeRenderer.theme_render(assigns, :cart) do
          {:ok, rendered} -> rendered
          :default -> Emakola.Themes.DefaultRenderers.Cart.render(assigns)
        end
      end

  Assigns required (set by `CartLive.mount/3` and the storefront `live_session`):

  - `:store` — resolved store struct
  - `:cart` — list of cart line items
  - `:cart_count` — total quantity
  - `:cart_total` — running subtotal in pesewas
  - `:coupon`, `:discount`, `:coupon_error`, `:coupon_input` — coupon UI state
  - `:flash` — Phoenix flash messages
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents

  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    ~H"""
    <Emakola.Themes.Atelier.Shared.navbar
      store={@store}
      categories={@categories}
      cart_count={@cart_count}
      active_path="cart"
    />

    <!-- PAGE HEADER -->
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-6 sm:pt-14 sm:pb-8">
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
        <div>
          <h1 class="font-serif text-3xl sm:text-4xl font-semibold text-cta-dark">Shopping Bag</h1>
          <p id="item-count-text" class="mt-1 text-sm text-[#78716C] font-light tracking-wide">
            {@cart_count} {if @cart_count == 1, do: "item", else: "items"}
          </p>
        </div>
        <.link
          navigate={"/s/#{@store.slug}"}
          class="inline-flex items-center gap-2 text-sm font-medium text-[#44403C] hover:text-store-accent transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded px-1 py-0.5 group"
        >
          <svg
            class="w-4 h-4 transition-transform group-hover:-translate-x-0.5"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path
              d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          Continue Shopping
        </.link>
      </div>
    </section>

    <!-- CART LAYOUT -->
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-20">
      <div class="lg:grid lg:grid-cols-[1fr_380px] lg:gap-12 xl:gap-16">
        <!-- ======= LEFT: Cart Items ======= -->
        <div id="cart-items">
          <%= if @cart == [] do %>
            <!-- Empty Cart State -->
            <div id="empty-cart" class="py-20 text-center">
              <svg
                class="w-16 h-16 mx-auto text-[#D6D3D1] mb-6"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                viewBox="0 0 24 24"
              >
                <path
                  d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
              <h2 class="font-serif text-2xl font-semibold text-cta-dark mb-2">Your bag is empty</h2>
              <p class="text-sm text-[#78716C] mb-8">
                Discover our curated collection and find something you love.
              </p>
              <.link
                navigate={"/s/#{@store.slug}"}
                class="inline-flex items-center gap-2 px-8 py-3 bg-cta-dark text-white text-sm font-semibold tracking-wider uppercase rounded-lg hover:bg-[#44403C] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none"
              >
                Start Shopping
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                </svg>
              </.link>
            </div>
          <% else %>
            <!-- Cart Items -->
            <div
              :for={{item, index} <- Enum.with_index(@cart)}
              class="cart-item py-6 border-b border-[#E7E5E4] group"
            >
              <div class="flex gap-4 sm:gap-6">
                <.link
                  navigate={"/s/#{@store.slug}/products/#{item.variant_id}"}
                  class="flex-shrink-0 cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded-xl overflow-hidden"
                  aria-label={"View #{item.product_title}"}
                >
                  <%= if item[:image_url] do %>
                    <img
                      src={item[:image_url]}
                      alt={item.product_title}
                      class="w-24 h-30 sm:w-32 sm:h-40 object-cover rounded-xl transition-transform duration-300 group-hover:scale-[1.02]"
                      loading="lazy"
                      width="200"
                      height="250"
                    />
                  <% else %>
                    <div class="w-24 h-30 sm:w-32 sm:h-40 bg-neutral-100 rounded-xl flex items-center justify-center text-neutral-300">
                      <svg
                        class="w-8 h-8"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                        />
                      </svg>
                    </div>
                  <% end %>
                </.link>
                <div class="flex-1 min-w-0 flex flex-col sm:flex-row sm:justify-between gap-4">
                  <div class="flex-1 min-w-0">
                    <.link
                      navigate={"/s/#{@store.slug}/products/#{item.variant_id}"}
                      class="font-serif text-lg sm:text-xl font-semibold text-cta-dark hover:text-store-accent transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded leading-tight"
                    >
                      {item.product_title}
                    </.link>
                    <div :if={item.variant_info} class="mt-2 space-y-0.5">
                      <p class="text-xs sm:text-sm text-[#78716C]">{item.variant_info}</p>
                    </div>
                    <p class="mt-2 text-base font-semibold text-cta-dark sm:hidden">
                      {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                    </p>
                    <div class="mt-3 flex items-center gap-4 sm:hidden">
                      <.quantity_stepper index={index} quantity={item.quantity} />
                      <button
                        phx-click="remove_item"
                        phx-value-index={index}
                        class="remove-btn text-[#78716C] hover:text-[#DC2626] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded p-1"
                        aria-label={"Remove #{item.product_title}"}
                      >
                        <svg
                          class="w-4 h-4"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          viewBox="0 0 24 24"
                        >
                          <path
                            d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                      </button>
                    </div>
                    <button class="wishlist-btn mt-3 inline-flex items-center gap-1.5 text-xs text-[#78716C] hover:text-store-accent transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded px-0.5 py-0.5">
                      <svg
                        class="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z"
                          stroke-linecap="round"
                          stroke-linejoin="round"
                        />
                      </svg>
                      Move to Wishlist
                    </button>
                  </div>
                  <div class="hidden sm:flex flex-col items-end justify-between flex-shrink-0 sm:min-w-[160px]">
                    <p class="text-base font-semibold text-cta-dark">
                      {Currency.format_price(item.unit_price, @store.currency)}
                    </p>
                    <.quantity_stepper index={index} quantity={item.quantity} />
                    <div class="flex items-center gap-1 mb-2 mt-2">
                      <span class="text-xs text-[#78716C]">Subtotal:</span>
                      <span class="item-subtotal text-sm font-semibold text-cta-dark">
                        {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                      </span>
                    </div>
                    <button
                      phx-click="remove_item"
                      phx-value-index={index}
                      class="remove-btn inline-flex items-center gap-1.5 text-xs text-[#78716C] hover:text-[#DC2626] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded px-0.5 py-0.5"
                      aria-label={"Remove #{item.product_title}"}
                    >
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                          stroke-linecap="round"
                          stroke-linejoin="round"
                        />
                      </svg>
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- ======= RIGHT: Order Summary ======= -->
        <div :if={@cart != []} id="order-summary-wrapper" class="mt-8 lg:mt-0">
          <div class="lg:sticky lg:top-28">
            <div class="bg-white rounded-2xl border border-[#E7E5E4] p-6 sm:p-8 shadow-sm">
              <h2 class="font-serif text-2xl font-semibold text-cta-dark mb-6">Order Summary</h2>

              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-[#78716C]">Subtotal</span>
                  <span id="summary-subtotal" class="font-medium text-cta-dark">
                    {Currency.format_price(@cart_subtotal, @store.currency)}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-[#78716C]">Shipping</span>
                  <span class="font-medium text-[#16A34A]">Free</span>
                </div>
                <p class="text-xs text-[#78716C]">Free shipping on orders over $200</p>
                <div class="flex justify-between">
                  <span class="text-[#78716C]">Estimated Tax</span>
                  <span id="summary-tax" class="font-medium text-cta-dark">
                    {Currency.format_price(@cart_tax, @store.currency)}
                  </span>
                </div>
              </div>

              <div class="border-t border-[#E7E5E4] my-5"></div>
              
    <!-- Promo Code -->
              <div id="promo-section">
                <label
                  for="promo-input"
                  class="block text-xs font-semibold tracking-wider uppercase text-[#44403C] mb-2"
                >
                  Promo Code
                </label>
                <form phx-submit="apply_promo" class="flex gap-2">
                  <input
                    id="promo-input"
                    name="promo"
                    type="text"
                    placeholder="Enter code"
                    disabled={@promo_code != nil}
                    class="flex-1 h-10 px-3 text-sm border border-[#E7E5E4] rounded-lg bg-transparent text-cta-dark placeholder:text-[#78716C]/60 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#CA8A04] transition-shadow disabled:opacity-50 disabled:cursor-not-allowed"
                    autocomplete="off"
                  />
                  <button
                    type="submit"
                    disabled={@promo_code != nil}
                    class="h-10 px-5 text-xs font-semibold tracking-wider uppercase bg-cta-dark text-white rounded-lg hover:bg-[#44403C] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Apply
                  </button>
                </form>
                <div :if={@promo_code} id="promo-success" class="mt-3 promo-success">
                  <div class="flex items-center gap-2 px-3 py-2 bg-green-50 border border-green-200 rounded-lg">
                    <svg
                      class="w-4 h-4 text-[#16A34A] flex-shrink-0"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path
                        d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                    </svg>
                    <span class="text-xs font-medium text-green-800">
                      {@promo_code} applied &mdash; 10% off
                    </span>
                    <button
                      type="button"
                      phx-click="remove_promo"
                      class="ml-auto text-green-600 hover:text-green-800 transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded"
                      aria-label="Remove promo code"
                    >
                      <svg
                        class="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        viewBox="0 0 24 24"
                      >
                        <path d="M6 18 18 6M6 6l12 12" stroke-linecap="round" stroke-linejoin="round" />
                      </svg>
                    </button>
                  </div>
                </div>
                <div :if={@promo_error} id="promo-error" class="mt-2">
                  <p class="text-xs text-[#DC2626]">{@promo_error}</p>
                </div>
              </div>
              
    <!-- Discount line -->
              <div :if={@cart_discount > 0} id="discount-line" class="mt-4">
                <div class="flex justify-between text-sm">
                  <span class="text-[#16A34A] font-medium">Discount (10%)</span>
                  <span id="summary-discount" class="font-medium text-[#16A34A]">
                    -{Currency.format_price(@cart_discount, @store.currency)}
                  </span>
                </div>
              </div>

              <div class="border-t border-[#E7E5E4] my-5"></div>
              
    <!-- Total -->
              <div class="flex justify-between items-center mb-6">
                <span class="text-base font-semibold text-cta-dark">Total</span>
                <span id="summary-total" class="text-2xl font-bold text-cta-dark font-sans">
                  {Currency.format_price(@cart_total, @store.currency)}
                </span>
              </div>
              
    <!-- Checkout Button -->
              <.link
                navigate={"/s/#{@store.slug}/checkout"}
                id="checkout-btn"
                class="flex items-center justify-center gap-2 w-full h-14 bg-store-accent text-white text-sm font-semibold tracking-widest uppercase rounded-xl hover:bg-[#A16207] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none shadow-lg shadow-[#CA8A04]/20"
              >
                <svg
                  class="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                </svg>
                Proceed to Checkout
              </.link>

              <%!-- Order via WhatsApp — only renders when merchant has set whatsapp_number.
                   Pre-fills cart contents into a WhatsApp DM the customer can review/send. --%>
              <a
                :if={Emakola.Cart.WhatsappOrderText.link(@store, @cart, total: @cart_total)}
                href={Emakola.Cart.WhatsappOrderText.link(@store, @cart, total: @cart_total)}
                target="_blank"
                rel="noopener noreferrer"
                id="order-via-whatsapp-btn"
                class="mt-3 flex items-center justify-center gap-2 w-full h-12 bg-[#25D366] text-white text-sm font-semibold rounded-xl hover:bg-[#1FAF55] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#25D366] focus-visible:outline-none"
              >
                <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347" />
                </svg>
                Order via WhatsApp
              </a>
              
    <!-- Trust Badges -->
              <div class="mt-5 flex items-center justify-center gap-6 text-[#78716C]">
                <div class="flex items-center gap-1.5">
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path
                      d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <span class="text-xs font-medium">Secure Checkout</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path
                      d="M9 15 3 9m0 0 6-6M3 9h12a6 6 0 0 1 0 12h-3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <span class="text-xs font-medium">Free Returns</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============================================ -->
    <!-- YOU MAY ALSO LIKE -->
    <!-- ============================================ -->
    <section
      :if={@recommended_products != []}
      class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-20 sm:pb-28"
    >
      <div class="text-center mb-10">
        <h2 class="font-serif text-2xl sm:text-3xl font-semibold text-cta-dark">
          You May Also Like
        </h2>
        <p class="mt-2 text-sm text-[#78716C]">Curated selections to complement your style</p>
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        <a
          :for={product <- @recommended_products}
          href={"/s/#{@store.slug}/products/#{product.slug}"}
          class="group cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded-xl"
        >
          <div class="relative overflow-hidden rounded-xl bg-white border border-[#E7E5E4] aspect-[3/4]">
            <%= if product.images != [] do %>
              <img
                src={List.first(product.images).url}
                alt={product.title}
                class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                loading="lazy"
              />
            <% else %>
              <div class="w-full h-full bg-neutral-100 flex items-center justify-center text-neutral-300">
                <svg
                  class="w-12 h-12"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                  />
                </svg>
              </div>
            <% end %>
            <div class="absolute inset-0 bg-gradient-to-t from-black/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
            </div>
          </div>
          <div class="mt-3 px-0.5">
            <h3 class="font-serif text-base sm:text-lg font-semibold text-cta-dark group-hover:text-store-accent transition-colors">
              {product.title}
            </h3>
            <p class="mt-0.5 text-sm font-medium text-[#44403C]">
              {Currency.format_price(product.min_price, @store.currency)}
            </p>
          </div>
        </a>
      </div>
    </section>

    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    <.bottom_nav store_slug={@store.slug} active_tab={:cart} cart_count={@cart_count} />
    """
  end

  attr :index, :integer, required: true
  attr :quantity, :integer, required: true

  defp quantity_stepper(assigns) do
    ~H"""
    <div class="inline-flex items-center overflow-hidden border rounded-lg border-[#E7E5E4]">
      <button
        disabled={@quantity <= 1}
        phx-click="update_quantity"
        phx-value-index={@index}
        phx-value-delta="-1"
        class="flex items-center justify-center w-8 h-8 sm:w-9 sm:h-9 text-[#44403C] hover:text-cta-dark hover:bg-gray-50 transition-colors cursor-pointer disabled:text-neutral-300 disabled:cursor-not-allowed"
        aria-label="Decrease quantity"
      >
        <svg
          class="w-3.5 h-3.5"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path d="M5 12h14" stroke-linecap="round" />
        </svg>
      </button>
      <div class="flex items-center justify-center w-10 text-sm font-medium bg-transparent border-x sm:w-12 h-8 sm:h-9 text-cta-dark border-[#E7E5E4]">
        {@quantity}
      </div>
      <button
        disabled={@quantity >= 10}
        phx-click="update_quantity"
        phx-value-index={@index}
        phx-value-delta="1"
        class="flex items-center justify-center w-8 h-8 sm:w-9 sm:h-9 text-[#44403C] hover:text-cta-dark hover:bg-gray-50 transition-colors cursor-pointer disabled:text-neutral-300 disabled:cursor-not-allowed"
        aria-label="Increase quantity"
      >
        <svg
          class="w-3.5 h-3.5"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path d="M12 5v14M5 12h14" stroke-linecap="round" />
        </svg>
      </button>
    </div>
    """
  end
end
