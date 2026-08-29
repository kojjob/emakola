defmodule Emakola.Themes.Market.ProductDetail do
  @moduledoc """
  Market theme — premium responsive product detail page renderer.

  Renders the product detail view with:
  - Responsive two-column layout (desktop) / single-column (mobile)
  - Image gallery with thumbnails (desktop) and dot indicators (mobile)
  - Variant selectors with pill-style buttons
  - Quantity stepper + Add to Bag CTA + WhatsApp button
  - Trust badges (shipping, secure, returns)
  - Accordion sections for details, shipping, returns
  - Related products grid (desktop) / horizontal scroll (mobile)
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  import EmakolaWeb.StorefrontComponents,
    only: [image_placeholder: 1, optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency
  alias Emakola.Themes.Delivery
  alias Emakola.Themes.Market.Shared

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-stone-50">
      <Shared.market_nav
        store={@store}
        categories={assigns[:categories] || []}
        cart_count={@cart_count}
      />

      <%!-- Breadcrumb (desktop only) --%>
      <nav
        class="hidden lg:block max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4"
        aria-label="Breadcrumb"
      >
        <ol class="flex items-center gap-2 text-sm text-stone-400">
          <li>
            <a href={store_path(@store.slug, "/")} class="hover:text-stone-600 transition-colors">
              {@store.name}
            </a>
          </li>
          <li>
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
            </svg>
          </li>
          <li>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-stone-600 transition-colors"
            >
              Products
            </a>
          </li>
          <li>
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
            </svg>
          </li>
          <li class="text-stone-900 font-medium truncate max-w-[200px]">{@product.title}</li>
        </ol>
      </nav>

      <%!-- Main Product Section --%>
      <main class="max-w-7xl mx-auto lg:px-8">
        <div class="lg:grid lg:grid-cols-2 lg:gap-12 xl:gap-16">
          <%!-- ═══════════ Image Gallery Column ═══════════ --%>
          <div class="lg:sticky lg:top-20 lg:self-start">
            <%!-- Primary Image --%>
            <div class="w-full aspect-[4/5] lg:aspect-[3/4] overflow-hidden bg-stone-100 lg:rounded-2xl">
              <%= if Shared.current_image(@product, @current_image_index) do %>
                <.optimized_image
                  src={Shared.current_image(@product, @current_image_index)}
                  alt={"#{@product.title} — image #{@current_image_index + 1}"}
                  priority={:high}
                  class="w-full h-full object-cover transition-opacity duration-300"
                  id="pdp-primary-image"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <.image_placeholder size="lg" />
                </div>
              <% end %>
            </div>

            <%!-- Mobile Dot Indicators --%>
            <div
              :if={length(@product.images) > 1}
              class="flex items-center justify-center gap-2 py-3 px-4 lg:hidden"
              role="tablist"
              aria-label="Product image thumbnails"
            >
              <button
                :for={{_img, idx} <- Enum.with_index(@product.images)}
                phx-click="select_image"
                phx-value-index={idx}
                role="tab"
                aria-selected={idx == @current_image_index}
                aria-label={"Image #{idx + 1}"}
                class={[
                  "h-2 rounded-full border-none transition-all cursor-pointer",
                  if(idx == @current_image_index,
                    do: "w-6 bg-store-accent",
                    else: "w-2 bg-stone-300 hover:bg-stone-400"
                  )
                ]}
              />
            </div>

            <%!-- Desktop Thumbnail Strip --%>
            <div
              :if={length(@product.images) > 1}
              class="hidden lg:grid grid-cols-4 gap-2.5 mt-3"
            >
              <button
                :for={{_img, idx} <- Enum.with_index(@product.images)}
                phx-click="select_image"
                phx-value-index={idx}
                class={[
                  "aspect-square rounded-xl overflow-hidden border-2 transition-all cursor-pointer hover:opacity-100",
                  if(idx == @current_image_index,
                    do: "border-store-accent opacity-100 ring-1 ring-store-accent/30",
                    else: "border-transparent opacity-70 hover:border-stone-300"
                  )
                ]}
                aria-label={"View image #{idx + 1}"}
              >
                <.optimized_image
                  src={Shared.current_image(@product, idx)}
                  alt={"#{@product.title} thumbnail #{idx + 1}"}
                  priority={:low}
                  class="w-full h-full object-cover"
                />
              </button>
            </div>
          </div>

          <%!-- ═══════════ Product Info Column ═══════════ --%>
          <div class="bg-white lg:bg-transparent">
            <%!-- Product Header --%>
            <section class="px-4 sm:px-6 lg:px-0 pt-5 lg:pt-2 pb-5 border-b border-stone-200 lg:border-none">
              <%!-- Badge — only for genuinely recent products --%>
              <span
                :if={new_arrival?(@product)}
                class="inline-flex items-center gap-1.5 bg-gradient-to-r from-amber-100 to-amber-200 text-amber-800 text-[0.6875rem] font-bold tracking-wider uppercase px-3 py-1 rounded-full mb-3"
              >
                <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                New Arrival
              </span>

              <%!-- Title --%>
              <h1 class="text-2xl lg:text-3xl xl:text-[2rem] font-bold text-stone-900 leading-tight mb-2">
                {@product.title}
              </h1>

              <Emakola.Themes.Shared.RealPhotoBadge.badge product={@product} />

              <%!-- Price --%>
              <div class="flex items-baseline gap-2.5 mb-3">
                <p class="text-2xl lg:text-[1.75rem] font-bold text-stone-900 tabular-nums">
                  <%= if @selected_variant do %>
                    {Currency.format_price(@selected_variant.price, @store.currency)}
                  <% else %>
                    {Currency.format_price_range(
                      @product.min_price,
                      @product.max_price,
                      @store.currency
                    )}
                  <% end %>
                </p>
                <%= if @selected_variant && @selected_variant.compare_at_price && @selected_variant.compare_at_price > @selected_variant.price do %>
                  <p class="text-base text-stone-400 line-through tabular-nums">
                    {Currency.format_price(@selected_variant.compare_at_price, @store.currency)}
                  </p>
                  <span class="text-xs font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full">
                    Save {Currency.format_price(
                      @selected_variant.compare_at_price - @selected_variant.price,
                      @store.currency
                    )}
                  </span>
                <% end %>
              </div>

              <%!-- Stock --%>
              <div class="mb-4">
                <.stock_badge variant={@selected_variant} />
              </div>

              <%!-- Description --%>
              <p :if={@product.description} class="text-[0.9375rem] text-stone-600 leading-relaxed">
                {@product.description}
              </p>
            </section>

            <%!-- Variant Selectors --%>
            <section
              :if={@option_types != []}
              class="px-4 sm:px-6 lg:px-0 py-5 border-b border-stone-200 lg:border-b lg:border-stone-200/60 space-y-5"
              aria-label="Product options"
            >
              <div :for={ot <- @option_types}>
                <div class="text-sm font-semibold text-stone-900 mb-3 flex items-center gap-2">
                  <span>{ot.name}</span>
                  <%= if Map.get(@selected_options, ot.id) do %>
                    <% selected_ov =
                      Enum.find(ot.option_values, fn ov ->
                        ov.id == Map.get(@selected_options, ot.id)
                      end) %>
                    <span :if={selected_ov} class="text-stone-400 font-normal">
                      — {selected_ov.value}
                    </span>
                  <% end %>
                </div>
                <div class="flex gap-2.5 flex-wrap" role="radiogroup" aria-label={"Select #{ot.name}"}>
                  <button
                    :for={ov <- ot.option_values}
                    phx-click="select_option"
                    phx-value-option_type_id={ot.id}
                    phx-value-option_value_id={ov.id}
                    role="radio"
                    aria-checked={Map.get(@selected_options, ot.id) == ov.id}
                    class={[
                      "min-w-[52px] h-11 px-5 rounded-full text-sm font-medium flex items-center justify-center transition-all duration-200 cursor-pointer",
                      if(Map.get(@selected_options, ot.id) == ov.id,
                        do: "bg-stone-900 text-white shadow-md",
                        else:
                          "bg-white text-stone-900 border-[1.5px] border-stone-200 hover:border-stone-900 hover:shadow-sm"
                      )
                    ]}
                  >
                    {ov.value}
                  </button>
                </div>
              </div>
            </section>

            <%!-- Quantity + Add to Bag --%>
            <section
              class="px-4 sm:px-6 lg:px-0 py-5 border-b border-stone-200 lg:border-b lg:border-stone-200/60 space-y-4"
              aria-label="Add to bag"
            >
              <%!-- Quantity stepper --%>
              <div class="flex items-center gap-3">
                <span class="text-sm font-semibold text-stone-900">Quantity</span>
                <div class="flex items-center border-[1.5px] border-stone-200 rounded-full overflow-hidden bg-white">
                  <button
                    phx-click="decrement_quantity"
                    disabled={@quantity <= 1}
                    class="w-10 h-10 flex items-center justify-center text-stone-900 hover:bg-stone-50 transition-colors disabled:text-stone-300 disabled:cursor-not-allowed"
                    aria-label="Decrease quantity"
                  >
                    <svg
                      class="w-4 h-4"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2.5"
                      stroke-linecap="round"
                    >
                      <path d="M4 8h8" />
                    </svg>
                  </button>
                  <div class="w-10 h-10 flex items-center justify-center text-[0.9375rem] font-semibold text-stone-900 select-none border-x-[1.5px] border-stone-200">
                    {@quantity}
                  </div>
                  <button
                    phx-click="increment_quantity"
                    disabled={@quantity >= 10}
                    class="w-10 h-10 flex items-center justify-center text-stone-900 hover:bg-stone-50 transition-colors disabled:text-stone-300 disabled:cursor-not-allowed"
                    aria-label="Increase quantity"
                  >
                    <svg
                      class="w-4 h-4"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2.5"
                      stroke-linecap="round"
                    >
                      <path d="M8 4v8M4 8h8" />
                    </svg>
                  </button>
                </div>
              </div>

              <%!-- Add to Bag button --%>
              <button
                :if={not Emakola.Catalog.Variant.sold_out?(@selected_variant)}
                id="add-to-bag-btn"
                phx-click="add_to_cart"
                disabled={is_nil(@selected_variant)}
                class={[
                  "w-full h-[54px] rounded-xl text-base font-semibold flex items-center justify-center gap-2.5 transition-all duration-300 group",
                  if(
                    is_nil(@selected_variant),
                    do: "bg-stone-200 text-stone-400 cursor-not-allowed",
                    else:
                      "bg-stone-900 text-white hover:bg-stone-700 hover:shadow-lg active:scale-[0.98] cursor-pointer"
                  )
                ]}
              >
                <svg
                  class="w-5 h-5 group-hover:scale-110 transition-transform"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                  />
                </svg>
                <%= if is_nil(@selected_variant) do %>
                  Out of Stock
                <% else %>
                  Add to Bag
                <% end %>
              </button>

              <.back_in_stock
                :if={Emakola.Catalog.Variant.sold_out?(@selected_variant)}
                store={@store}
                product={@product}
              />

              <%!-- WhatsApp button (only when the store has a WhatsApp number) --%>
              <a
                :if={Shared.whatsapp_link(@store, @product.title)}
                href={Shared.whatsapp_link(@store, @product.title)}
                target="_blank"
                rel="noopener noreferrer"
                class="flex items-center justify-center gap-2.5 w-full h-12 border-[1.5px] border-stone-200 rounded-xl text-[0.9375rem] font-medium text-stone-900 hover:border-whatsapp hover:text-whatsapp hover:bg-whatsapp/5 transition-all duration-200 group"
              >
                <svg
                  class="w-5 h-5 text-whatsapp group-hover:scale-110 transition-transform"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                >
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                </svg>
                Ask on WhatsApp
              </a>

              <%!-- SKU --%>
              <p
                :if={@selected_variant && @selected_variant.sku}
                class="text-center text-xs text-stone-400 pt-0.5"
              >
                SKU: {@selected_variant.sku}
              </p>
            </section>

            <%!-- Trust Badges. Market's HOME trust strip has always been the
                 honest one — it links delivery and returns to the store's own
                 policies. Its PDP did not: it promised "Free Delivery — Orders
                 over GHS 500" and "Easy Returns — 7 day policy" on every
                 product, numbers no merchant had set. Now the delivery badge is
                 the store's own (absent when it has configured no zones) and
                 returns link where they always should have. --%>
            <section class="px-4 sm:px-6 lg:px-0 py-5 border-b border-stone-200 lg:border-b lg:border-stone-200/60">
              <div class="grid grid-cols-3 gap-3">
                <.trust_badge
                  :if={Delivery.callout(assigns)}
                  icon="truck"
                  title="Delivery"
                  subtitle={Delivery.callout(assigns)}
                />
                <.trust_badge
                  icon="shield"
                  title="Secure Payment"
                  subtitle="Processed securely"
                />
                <.trust_badge
                  icon="refresh"
                  title="Returns"
                  subtitle="See this store's policies"
                  href={store_path(@store.slug, "/policies#returns")}
                />
              </div>
            </section>

            <%!-- Accordion Sections --%>
            <div class="bg-white lg:bg-transparent">
              <details class="group border-b border-stone-200 lg:border-stone-200/60">
                <summary class="px-4 sm:px-6 lg:px-0 py-4 text-[0.9375rem] font-semibold text-stone-900 cursor-pointer flex items-center justify-between hover:text-store-accent transition-colors select-none list-none [&::-webkit-details-marker]:hidden">
                  <div class="flex items-center gap-2.5">
                    <svg
                      class="w-5 h-5 text-stone-400"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"
                      />
                    </svg>
                    Product Details
                  </div>
                  <svg
                    class="w-5 h-5 text-stone-400 transition-transform duration-300 group-open:rotate-180"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="2"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                    />
                  </svg>
                </summary>
                <div class="px-4 sm:px-6 lg:px-0 pb-5 text-sm text-stone-600 leading-relaxed">
                  <p :if={@product.description}>{@product.description}</p>
                  <p :if={!@product.description}>No additional details available.</p>
                </div>
              </details>
              <details class="group border-b border-stone-200 lg:border-stone-200/60">
                <summary class="px-4 sm:px-6 lg:px-0 py-4 text-[0.9375rem] font-semibold text-stone-900 cursor-pointer flex items-center justify-between hover:text-store-accent transition-colors select-none list-none [&::-webkit-details-marker]:hidden">
                  <div class="flex items-center gap-2.5">
                    <svg
                      class="w-5 h-5 text-stone-400"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                      />
                    </svg>
                    Shipping & Delivery
                  </div>
                  <svg
                    class="w-5 h-5 text-stone-400 transition-transform duration-300 group-open:rotate-180"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="2"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                    />
                  </svg>
                </summary>
                <div class="px-4 sm:px-6 lg:px-0 pb-5 text-sm text-stone-600 leading-relaxed">
                  <p>
                    See our
                    <a
                      href={store_path(@store.slug, "/policies")}
                      class="underline hover:text-store-accent"
                    >
                      delivery information
                    </a>
                    on the policies page.
                  </p>
                </div>
              </details>
              <details class="group border-b border-stone-200 lg:border-stone-200/60">
                <summary class="px-4 sm:px-6 lg:px-0 py-4 text-[0.9375rem] font-semibold text-stone-900 cursor-pointer flex items-center justify-between hover:text-store-accent transition-colors select-none list-none [&::-webkit-details-marker]:hidden">
                  <div class="flex items-center gap-2.5">
                    <svg
                      class="w-5 h-5 text-stone-400"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182M21.015 4.356v4.992"
                      />
                    </svg>
                    Returns & Exchange
                  </div>
                  <svg
                    class="w-5 h-5 text-stone-400 transition-transform duration-300 group-open:rotate-180"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="2"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                    />
                  </svg>
                </summary>
                <div class="px-4 sm:px-6 lg:px-0 pb-5 text-sm text-stone-600 leading-relaxed">
                  <p>
                    See our
                    <a
                      href={store_path(@store.slug, "/policies")}
                      class="underline hover:text-store-accent"
                    >
                      returns policy
                    </a>
                    on the policies page.
                  </p>
                </div>
              </details>
            </div>
          </div>
        </div>
      </main>

      <%!-- Related Products --%>
      <section :if={@related_products != []} class="py-10 lg:py-16 bg-white mt-6 lg:mt-12">
        <div class="max-w-7xl mx-auto">
          <div class="flex items-center justify-between px-4 sm:px-6 lg:px-8 mb-6 lg:mb-8">
            <h2 class="text-xl lg:text-2xl font-bold text-stone-900">You May Also Like</h2>
            <a
              href={store_path(@store.slug, "/products")}
              class="text-sm font-medium text-store-accent hover:text-amber-800 transition-colors flex items-center gap-1"
            >
              View All
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
              </svg>
            </a>
          </div>

          <%!-- Mobile: horizontal scroll --%>
          <div class="flex gap-3.5 overflow-x-auto px-4 sm:px-6 snap-x snap-mandatory [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden lg:hidden">
            <a
              :for={rp <- @related_products}
              href={store_path(@store.slug, "/products/#{rp.slug}")}
              class="flex-[0_0_160px] snap-start bg-white rounded-2xl border border-stone-200 overflow-hidden hover:shadow-md transition-all duration-200 group"
            >
              <div class="w-full aspect-square bg-stone-100 overflow-hidden">
                <%= if Shared.first_image(rp) do %>
                  <.optimized_image
                    src={Shared.first_image(rp)}
                    alt={rp.title}
                    class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  />
                <% else %>
                  <div class="w-full h-full flex items-center justify-center">
                    <.image_placeholder />
                  </div>
                <% end %>
              </div>
              <div class="p-3">
                <p class="text-sm font-medium text-stone-900 leading-tight mb-1 truncate">
                  {rp.title}
                </p>
                <p class="text-sm font-bold text-stone-900">
                  {Currency.format_price_range(rp.min_price, rp.max_price, @store.currency)}
                </p>
              </div>
            </a>
          </div>

          <%!-- Desktop: grid --%>
          <div class="hidden lg:grid lg:grid-cols-4 gap-5 px-8">
            <a
              :for={rp <- Enum.take(@related_products, 4)}
              href={store_path(@store.slug, "/products/#{rp.slug}")}
              class="bg-white rounded-2xl border border-stone-200 overflow-hidden hover:shadow-lg hover:border-stone-300 transition-all duration-300 group"
            >
              <div class="w-full aspect-[3/4] bg-stone-100 overflow-hidden">
                <%= if Shared.first_image(rp) do %>
                  <.optimized_image
                    src={Shared.first_image(rp)}
                    alt={rp.title}
                    class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                <% else %>
                  <div class="w-full h-full flex items-center justify-center">
                    <.image_placeholder />
                  </div>
                <% end %>
              </div>
              <div class="p-4">
                <p class="text-[0.9375rem] font-medium text-stone-900 leading-tight mb-1.5 truncate">
                  {rp.title}
                </p>
                <p class="text-[0.9375rem] font-bold text-stone-900">
                  {Currency.format_price_range(rp.min_price, rp.max_price, @store.currency)}
                </p>
              </div>
            </a>
          </div>
        </div>
      </section>

      <%!-- Customer Reviews --%>
      <EmakolaWeb.ReviewComponents.review_section
        store={@store}
        product={@product}
        reviews={@reviews}
        can_review={@can_review}
        already_reviewed={@already_reviewed}
        review_form={assigns[:review_form]}
        review_form_rating={@review_form_rating}
        review_form_title={@review_form_title}
        review_form_body={@review_form_body}
        review_submitting={@review_submitting}
        avg_rating={@product.avg_rating}
        review_count={@product.review_count}
        uploads={@uploads}
      />

      <%!-- Mobile spacer for bottom nav --%>
      <div class="h-16 sm:hidden"></div>
    </div>

    <Shared.footer
      store={@store}
      categories={assigns[:categories] || []}
      theme={assigns[:theme] || %{}}
    />

    <Shared.market_bottom_nav store={@store} cart_count={@cart_count} />
    """
  end

  # -- Helpers --

  # True when the product was added within the last 14 days.
  defp new_arrival?(product) do
    case Map.get(product, :inserted_at) do
      %DateTime{} = dt -> DateTime.diff(DateTime.utc_now(), dt, :day) <= 14
      %NaiveDateTime{} = ndt -> NaiveDateTime.diff(NaiveDateTime.utc_now(), ndt, :day) <= 14
      _ -> false
    end
  end

  # -- Components --

  attr :variant, :map, default: nil

  defp stock_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="inline-flex items-center gap-1.5 text-sm text-stone-400">
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M8.25 15L12 18.75 15.75 15m-7.5-6L12 5.25 15.75 9"
            />
          </svg>
          Select options
        </span>
      <% @variant.track_inventory and @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-red-600">
          <span class="w-2 h-2 rounded-full bg-red-500"></span> Out of Stock
        </span>
      <% @variant.track_inventory and @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-amber-600">
          <span class="w-2 h-2 rounded-full bg-amber-500 animate-pulse"></span>
          Only {@variant.stock_quantity} left — order soon!
        </span>
      <% true -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-600">
          <span class="w-2 h-2 rounded-full bg-emerald-600 animate-pulse"></span> In Stock
        </span>
    <% end %>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :href, :string, default: nil

  defp trust_badge(assigns) do
    ~H"""
    <div class="flex flex-col items-center text-center p-3 rounded-xl bg-stone-50 border border-stone-200/60">
      <.trust_icon name={@icon} />
      <span class="text-xs font-semibold text-stone-900 mt-1.5 leading-tight">{@title}</span>
      <a
        :if={@href}
        href={@href}
        class="text-[0.625rem] text-stone-400 leading-tight mt-0.5 underline decoration-stone-300 underline-offset-2 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-store-accent rounded"
      >
        {@subtitle}
      </a>
      <span :if={!@href} class="text-[0.625rem] text-stone-400 leading-tight mt-0.5">
        {@subtitle}
      </span>
    </div>
    """
  end

  defp trust_icon(%{name: "truck"} = assigns) do
    ~H"""
    <svg
      class="w-5 h-5 text-store-accent"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
      />
    </svg>
    """
  end

  defp trust_icon(%{name: "shield"} = assigns) do
    ~H"""
    <svg
      class="w-5 h-5 text-store-accent"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
      />
    </svg>
    """
  end

  defp trust_icon(%{name: "refresh"} = assigns) do
    ~H"""
    <svg
      class="w-5 h-5 text-store-accent"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182M21.015 4.356v4.992"
      />
    </svg>
    """
  end

  defp trust_icon(assigns), do: ~H""

  defp shop_initial(store) do
    case store |> Map.get(:name) |> to_string() |> String.first() do
      nil -> "?"
      letter -> String.upcase(letter)
    end
  end

  # ── Back in Stock ──
  #
  # Market is a stall, so this is addressed to the seller rather than announced
  # by the site. The bubble is a shape, not a quote: nothing here is put in the
  # merchant's mouth, and no reply time is promised on their behalf.
  attr :store, :map, required: true
  attr :product, :map, required: true

  defp back_in_stock(assigns) do
    assigns =
      assign(
        assigns,
        :url,
        Emakola.Themes.BackInStock.whatsapp_url(assigns.store, assigns.product)
      )

    ~H"""
    <div
      :if={@url}
      id="back-in-stock"
      class="flex items-start gap-3.5 border-t-2 border-[var(--theme-accent,#B45309)] pt-[18px]"
    >
      <div class="flex h-[46px] w-[46px] shrink-0 items-center justify-center rounded-full bg-[#1C1917] text-[15px] font-bold text-[#FAFAF9]">
        {shop_initial(@store)}
      </div>
      <div class="min-w-0 flex-1">
        <div class="mb-3 rounded-[4px_16px_16px_16px] border border-stone-200 bg-white px-4 py-3.5">
          <p class="text-[13.5px] leading-relaxed text-stone-800">
            This one has finished. Message {@store.name} about it.
          </p>
        </div>
        <a
          href={@url}
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex h-11 items-center gap-2.5 rounded-xl bg-[#1C1917] px-5 text-[13.5px] font-bold text-[#FAFAF9] transition-colors hover:bg-[#292524]"
        >
          <EmakolaWeb.StorefrontComponents.whatsapp_glyph class="h-[17px] w-[17px] text-whatsapp" />
          Message the seller
        </a>
      </div>
    </div>
    """
  end
end
