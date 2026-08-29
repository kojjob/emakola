defmodule Emakola.Themes.Fie.ProductDetail do
  @moduledoc """
  Fie theme — product detail page: one catalogue plate, opened.

  Two columns on desktop: the plate gallery (blush ground composed before
  the photo arrives, thumbnails driving `select_image`) and the piece's
  entry — title, ink price with honest compare-at, stock line, variant
  radiogroups (`select_option`), quantity stepper, add to cart, WhatsApp
  ask, and promise-free accordions that defer delivery/returns to the
  store's own policies page. Reviews render when the LiveView provides
  the review assigns.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Fie.Components
  alias Emakola.Themes.Fie.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    ~H"""
    <div class="bg-[#FDFCFB]">
      <Shared.theme_styles theme={@theme} />
      <%!-- Theme banner nav: the bottom bar below is mobile-only, so without
      this the cart is unreachable from the product page on desktop. --%>
      <Shared.fie_nav
        store={@store}
        categories={assigns[:categories] || []}
        cart_count={assigns[:cart_count] || 0}
      />

      <div class="mx-auto max-w-[1200px] px-4 sm:px-6 lg:px-8">
        <nav aria-label="Breadcrumb" class="hidden pt-6 lg:block">
          <ol class="flex items-center gap-2 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
            <li>
              <a
                href={store_path(@store.slug, "/")}
                class="hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
              >
                {@store.name}
              </a>
            </li>
            <li aria-hidden="true">/</li>
            <li>
              <a
                href={store_path(@store.slug, "/products")}
                class="hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
              >
                Catalogue
              </a>
            </li>
            <li aria-hidden="true">/</li>
            <li class="max-w-[240px] truncate normal-case tracking-normal text-stone-900">
              {@product.title}
            </li>
          </ol>
        </nav>

        <div class="grid gap-8 pb-14 pt-6 lg:grid-cols-2 lg:gap-14 lg:pt-8">
          <%!-- Plate gallery --%>
          <div class="lg:sticky lg:top-24 lg:self-start">
            <div class="relative aspect-[4/5] w-full overflow-hidden border border-[#EBDAD3] bg-[#F7ECE7]">
              <div class="absolute inset-0 flex items-center justify-center">
                <span
                  class="select-none text-[6rem] font-medium text-[#D8BCB0] [font-family:'Space_Grotesk','Inter',sans-serif]"
                  aria-hidden="true"
                >
                  {String.first(@product.title)}
                </span>
              </div>
              <.optimized_image
                :if={Shared.current_image(@product, @current_image_index)}
                src={Shared.current_image(@product, @current_image_index)}
                alt={"#{@product.title} — image #{@current_image_index + 1}"}
                priority={:high}
                width={640}
                height={800}
                class="absolute inset-0 h-full w-full object-cover"
              />
            </div>

            <div
              :if={length(@product.images) > 1}
              class="mt-3 grid grid-cols-5 gap-2"
              role="group"
              aria-label="Product images"
            >
              <button
                :for={{_image, index} <- Enum.with_index(@product.images)}
                phx-click="select_image"
                phx-value-index={index}
                aria-label={"View image #{index + 1}"}
                aria-current={index == @current_image_index && "true"}
                class={[
                  "aspect-square cursor-pointer overflow-hidden border focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
                  if(index == @current_image_index,
                    do: "border-stone-900",
                    else: "border-[#EBDAD3] opacity-70 hover:opacity-100"
                  )
                ]}
              >
                <.optimized_image
                  :if={Shared.current_image(@product, index)}
                  src={Shared.current_image(@product, index)}
                  alt=""
                  priority={:low}
                  width={96}
                  height={96}
                  class="h-full w-full object-cover"
                />
              </button>
            </div>
          </div>

          <%!-- The entry --%>
          <div>
            <h1 class="text-3xl font-medium leading-tight tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif] sm:text-4xl">
              {@product.title}
            </h1>

            <Emakola.Themes.Shared.RealPhotoBadge.badge product={@product} />

            <div class="mt-4 flex flex-wrap items-baseline gap-x-3 gap-y-1 border-b border-[#EBDAD3] pb-5">
              <p class="text-2xl font-medium tabular-nums tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif]">
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
              <%= if @selected_variant && @selected_variant.compare_at_price &&
                    @selected_variant.compare_at_price > @selected_variant.price do %>
                <s class="text-base tabular-nums text-stone-400 line-through">
                  <span class="sr-only">was</span>
                  {Currency.format_price(@selected_variant.compare_at_price, @store.currency)}
                </s>
                <span class="text-xs font-semibold text-store-accent">
                  Save {Currency.format_price(
                    @selected_variant.compare_at_price - @selected_variant.price,
                    @store.currency
                  )}
                </span>
              <% end %>
              <span class="basis-full"></span>
              <.stock_line variant={@selected_variant} />
            </div>

            <p :if={@product.description} class="mt-5 text-[0.9375rem] leading-relaxed text-stone-600">
              {@product.description}
            </p>

            <section
              :if={@option_types != []}
              class="mt-7 space-y-6"
              aria-label="Product options"
            >
              <div :for={option_type <- @option_types}>
                <p class="mb-3 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
                  {option_type.name}
                </p>
                <div
                  class="flex flex-wrap gap-2"
                  role="radiogroup"
                  aria-label={"Select #{option_type.name}"}
                >
                  <button
                    :for={option_value <- option_type.option_values}
                    phx-click="select_option"
                    phx-value-option_type_id={option_type.id}
                    phx-value-option_value_id={option_value.id}
                    role="radio"
                    aria-checked={
                      to_string(Map.get(@selected_options, option_type.id) == option_value.id)
                    }
                    class={[
                      "flex min-h-[44px] min-w-[52px] cursor-pointer items-center justify-center border px-5 text-sm font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do: "border-stone-900 bg-stone-900 text-white",
                        else: "border-[#EBDAD3] bg-white text-stone-900 hover:border-stone-400"
                      )
                    ]}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </section>

            <section class="mt-7 space-y-4" aria-label="Add to cart">
              <div class="flex items-center gap-3">
                <span class="text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
                  Quantity
                </span>
                <div class="flex items-center border border-[#EBDAD3] bg-white">
                  <button
                    phx-click="decrement_quantity"
                    disabled={@quantity <= 1}
                    class="flex h-11 w-11 cursor-pointer items-center justify-center text-stone-900 hover:bg-[#F7ECE7] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 disabled:cursor-not-allowed disabled:text-stone-300 motion-safe:transition-colors"
                    aria-label="Decrease quantity"
                  >
                    <svg
                      class="h-4 w-4"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                      aria-hidden="true"
                    >
                      <path stroke-linecap="round" d="M5 12h14" />
                    </svg>
                  </button>
                  <span class="flex h-11 w-11 select-none items-center justify-center border-x border-[#EBDAD3] text-sm font-semibold tabular-nums text-stone-900">
                    {@quantity}
                  </span>
                  <button
                    phx-click="increment_quantity"
                    disabled={@quantity >= 10}
                    class="flex h-11 w-11 cursor-pointer items-center justify-center text-stone-900 hover:bg-[#F7ECE7] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 disabled:cursor-not-allowed disabled:text-stone-300 motion-safe:transition-colors"
                    aria-label="Increase quantity"
                  >
                    <svg
                      class="h-4 w-4"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                      aria-hidden="true"
                    >
                      <path stroke-linecap="round" d="M12 4.5v15m7.5-7.5h-15" />
                    </svg>
                  </button>
                </div>
              </div>

              <%!-- Built from the store's own delivery zones; renders nothing when it
                   has configured none. Never a theme default — a hardcoded "free
                   delivery in Accra" would be a promise the merchant never made. --%>
              <p
                :if={Emakola.Themes.Delivery.callout(assigns)}
                class="mb-3 flex items-center gap-2 text-sm font-medium"
              >
                <span
                  aria-hidden="true"
                  class="inline-block h-1.5 w-1.5 rounded-full bg-current opacity-60"
                />
                {Emakola.Themes.Delivery.callout(assigns)}
              </p>
              <button
                id="fie-add-to-cart"
                phx-click="add_to_cart"
                disabled={!purchasable?(@selected_variant)}
                class={[
                  "flex min-h-[52px] w-full items-center justify-center gap-2.5 px-6 text-[0.9375rem] font-semibold leading-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-opacity",
                  if(purchasable?(@selected_variant),
                    do:
                      "cursor-pointer bg-store-accent text-white hover:opacity-90 motion-safe:active:scale-[0.99]",
                    else: "cursor-not-allowed bg-[#F7ECE7] text-stone-400"
                  )
                ]}
              >
                <%= if purchasable?(@selected_variant) do %>
                  Add to cart
                <% else %>
                  {if @selected_variant, do: "Out of stock", else: "Select options"}
                <% end %>
              </button>

              <a
                :if={Shared.whatsapp_link(@store, @product.title)}
                href={Shared.whatsapp_link(@store, @product.title)}
                target="_blank"
                rel="noopener noreferrer"
                class="flex min-h-[48px] w-full items-center justify-center gap-2.5 border border-[#EBDAD3] bg-white px-6 text-sm font-medium text-stone-900 hover:border-whatsapp hover:text-whatsapp focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
              >
                <svg
                  class="h-4.5 w-4.5 text-whatsapp"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                  <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
                </svg>
                Ask on WhatsApp
              </a>

              <p
                :if={@selected_variant && @selected_variant.sku}
                class="text-center text-xs tabular-nums text-stone-400"
              >
                SKU: {@selected_variant.sku}
              </p>
            </section>

            <div class="mt-8 border-t border-[#EBDAD3]">
              <details class="group border-b border-[#EBDAD3]">
                <summary class="flex min-h-[52px] cursor-pointer select-none list-none items-center justify-between py-4 text-sm font-semibold text-stone-900 hover:text-store-accent motion-safe:transition-colors [&::-webkit-details-marker]:hidden">
                  Piece details
                  <svg
                    class="h-4 w-4 text-stone-400 motion-safe:transition-transform motion-safe:duration-200 group-open:rotate-180"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="2"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                    />
                  </svg>
                </summary>
                <div class="pb-5 text-sm leading-relaxed text-stone-600">
                  <p :if={@product.description}>{@product.description}</p>
                  <p :if={!@product.description}>No additional details available.</p>
                </div>
              </details>
              <details class="group border-b border-[#EBDAD3]">
                <summary class="flex min-h-[52px] cursor-pointer select-none list-none items-center justify-between py-4 text-sm font-semibold text-stone-900 hover:text-store-accent motion-safe:transition-colors [&::-webkit-details-marker]:hidden">
                  Delivery &amp; returns
                  <svg
                    class="h-4 w-4 text-stone-400 motion-safe:transition-transform motion-safe:duration-200 group-open:rotate-180"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="2"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                    />
                  </svg>
                </summary>
                <div class="pb-5 text-sm leading-relaxed text-stone-600">
                  <p>
                    See
                    <a
                      href={store_path(@store.slug, "/policies#shipping")}
                      class="underline decoration-[#D8BCB0] underline-offset-2 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
                    >
                      this store's policies
                    </a>
                    for delivery and returns.
                  </p>
                </div>
              </details>
            </div>
          </div>
        </div>
      </div>

      <%!-- Also in the catalogue --%>
      <section
        :if={@related_products != []}
        class="border-t border-[#EBDAD3]"
        aria-labelledby="fie-related-heading"
      >
        <div class="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
          <div class="mb-6 flex items-baseline justify-between gap-4">
            <h2
              id="fie-related-heading"
              class="text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500"
            >
              Also in the catalogue
            </h2>
            <a
              href={store_path(@store.slug, "/products")}
              class="text-xs font-medium text-stone-600 underline decoration-[#D8BCB0] underline-offset-2 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
            >
              Open the catalogue
            </a>
          </div>
          <%!-- Link-only plates: this LiveView's add_to_cart adds the current
          product's selected variant regardless of payload, so a quick-add
          here would put the wrong piece in the cart. --%>
          <div class="grid grid-cols-2 gap-x-4 gap-y-8 md:grid-cols-4 md:gap-x-5">
            <Components.catalogue_plate
              :for={related <- Enum.take(@related_products, 4)}
              product={related}
              store={@store}
              add_to_cart={false}
            />
          </div>
        </div>
      </section>

      <%!-- Customer reviews (LiveView-provided assigns) --%>
      <div :if={assigns[:reviews] != nil} class="border-t border-[#EBDAD3]">
        <EmakolaWeb.ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={assigns[:reviews] || []}
          can_review={assigns[:can_review] || false}
          already_reviewed={assigns[:already_reviewed] || false}
          review_form={assigns[:review_form]}
          review_form_rating={assigns[:review_form_rating] || 0}
          review_form_title={assigns[:review_form_title] || ""}
          review_form_body={assigns[:review_form_body] || ""}
          review_submitting={assigns[:review_submitting] || false}
          avg_rating={Map.get(@product, :avg_rating)}
          review_count={Map.get(@product, :review_count) || 0}
          uploads={assigns[:uploads]}
        />
      </div>

      <%!-- Mobile spacer clears the fixed bottom tab bar --%>
      <div class="h-16 sm:hidden"></div>
    </div>

    <Shared.footer
      store={@store}
      categories={assigns[:categories] || []}
      theme={@theme}
    />
    <Shared.fie_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} active={:none} />
    """
  end

  defp purchasable?(nil), do: false
  defp purchasable?(variant), do: Emakola.Catalog.Variant.in_stock?(variant)

  attr :variant, :map, default: nil

  defp stock_line(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="text-xs font-medium text-stone-500">Select options</span>
      <% @variant.track_inventory and @variant.stock_quantity <= 0 -> %>
        <span class="text-xs font-medium text-stone-500">Out of stock</span>
      <% @variant.track_inventory and @variant.stock_quantity < 5 -> %>
        <span class="text-xs font-medium tabular-nums text-store-accent">
          Only {@variant.stock_quantity} left
        </span>
      <% true -> %>
        <span class="text-xs font-medium text-stone-600">In stock</span>
    <% end %>
    """
  end
end
