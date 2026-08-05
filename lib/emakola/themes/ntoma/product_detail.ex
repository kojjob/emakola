defmodule Emakola.Themes.Ntoma.ProductDetail do
  @moduledoc """
  Ntoma theme — product detail page renderer.

  Editorial piece page: Ntoma's banner nav, a placeholder-first gallery
  (serif initial until the photograph arrives), serif display title,
  garment-label pricing, variant selectors, quantity stepper, add-to-cart
  and WhatsApp ask, honest delivery/returns accordions that defer to the
  store's own policies page, related pieces, and customer reviews.

  Related-product cards render browse-only: this LiveView's `add_to_cart`
  handler adds the *selected variant of the page's product*, so a buy
  button on a related card would add the wrong item.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Ntoma.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    ~H"""
    <Shared.ntoma_nav store={@store} categories={@categories} cart_count={@cart_count} />

    <div class="bg-[#FAF4EA]">
      <nav
        class="mx-auto hidden max-w-[1280px] px-4 py-4 sm:px-6 lg:block lg:px-8"
        aria-label="Breadcrumb"
      >
        <ol class="flex items-center gap-2 text-xs font-medium uppercase tracking-[0.08em] text-[#A08863]">
          <li>
            <a
              href={store_path(@store.slug, "/")}
              class="hover:text-[#2B1708] motion-safe:transition-colors"
            >
              {@store.name}
            </a>
          </li>
          <li aria-hidden="true">/</li>
          <li>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-[#2B1708] motion-safe:transition-colors"
            >
              The Collection
            </a>
          </li>
          <li aria-hidden="true">/</li>
          <li class="max-w-[240px] truncate text-[#2B1708]">{@product.title}</li>
        </ol>
      </nav>

      <div class="mx-auto max-w-[1280px] px-4 pb-10 pt-4 sm:px-6 lg:grid lg:grid-cols-2 lg:gap-12 lg:px-8 lg:pt-6 xl:gap-16">
        <%!-- Gallery --%>
        <div class="lg:sticky lg:top-24 lg:self-start">
          <div class="relative aspect-[4/5] overflow-hidden border border-[#E6D5B8] bg-[#F0E3CE]">
            <div class="absolute inset-0 flex items-center justify-center" aria-hidden="true">
              <span class="select-none text-9xl font-semibold text-[#CFB183] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]">
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

          <%!-- Mobile dot indicators --%>
          <div
            :if={length(@product.images) > 1}
            class="flex items-center justify-center gap-2 px-4 py-3 lg:hidden"
            role="tablist"
            aria-label="Product images"
          >
            <button
              :for={{_img, idx} <- Enum.with_index(@product.images)}
              phx-click="select_image"
              phx-value-index={idx}
              role="tab"
              aria-selected={idx == @current_image_index}
              aria-label={"Image #{idx + 1}"}
              class={[
                "h-2 cursor-pointer border-none motion-safe:transition-all",
                if(idx == @current_image_index,
                  do: "w-6 bg-[#2B1708]",
                  else: "w-2 bg-[#CFB183] hover:bg-[#A08863]"
                )
              ]}
            />
          </div>

          <%!-- Desktop thumbnails --%>
          <div :if={length(@product.images) > 1} class="mt-3 hidden grid-cols-4 gap-2.5 lg:grid">
            <button
              :for={{_img, idx} <- Enum.with_index(@product.images)}
              phx-click="select_image"
              phx-value-index={idx}
              aria-label={"View image #{idx + 1}"}
              class={[
                "aspect-square cursor-pointer overflow-hidden border-2 motion-safe:transition-all",
                if(idx == @current_image_index,
                  do: "border-[#2B1708]",
                  else: "border-transparent opacity-70 hover:border-[#CFB183] hover:opacity-100"
                )
              ]}
            >
              <.optimized_image
                src={Shared.current_image(@product, idx)}
                alt={"#{@product.title} thumbnail #{idx + 1}"}
                priority={:low}
                width={160}
                height={160}
                class="h-full w-full object-cover"
              />
            </button>
          </div>
        </div>

        <%!-- Info --%>
        <div class="pt-6 lg:pt-0">
          <h1 class="text-3xl font-semibold leading-tight text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-4xl">
            {@product.title}
          </h1>

          <div class="mt-4 flex flex-wrap items-baseline gap-3">
            <p class="text-2xl font-semibold tabular-nums text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-[1.75rem]">
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
            <p
              :if={
                @selected_variant && @selected_variant.compare_at_price &&
                  @selected_variant.compare_at_price > @selected_variant.price
              }
              class="text-base tabular-nums text-[#A08863] line-through"
            >
              {Currency.format_price(@selected_variant.compare_at_price, @store.currency)}
            </p>
          </div>

          <div class="mt-3">
            <.stock_badge variant={@selected_variant} />
          </div>

          <p
            :if={@product.description}
            class="mt-5 text-[0.9375rem] leading-relaxed text-[#7A6248]"
          >
            {@product.description}
          </p>

          <%!-- Variant selectors --%>
          <section
            :if={@option_types != []}
            class="mt-7 space-y-5 border-t border-[#E6D5B8] pt-6"
            aria-label="Product options"
          >
            <div :for={option_type <- @option_types}>
              <div class="mb-3 text-sm font-semibold uppercase tracking-[0.08em] text-[#2B1708]">
                {option_type.name}
              </div>
              <div
                class="flex flex-wrap gap-2.5"
                role="radiogroup"
                aria-label={"Select #{option_type.name}"}
              >
                <button
                  :for={option_value <- option_type.option_values}
                  phx-click="select_option"
                  phx-value-option_type_id={option_type.id}
                  phx-value-option_value_id={option_value.id}
                  role="radio"
                  aria-checked={Map.get(@selected_options, option_type.id) == option_value.id}
                  class={[
                    "flex h-11 min-w-[52px] cursor-pointer items-center justify-center border px-5 text-sm font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-colors",
                    if(Map.get(@selected_options, option_type.id) == option_value.id,
                      do: "border-[#2B1708] bg-[#2B1708] text-[#FAF4EA]",
                      else: "border-[#E6D5B8] bg-[#FFFBF2] text-[#2B1708] hover:border-[#2B1708]"
                    )
                  ]}
                >
                  {option_value.value}
                </button>
              </div>
            </div>
          </section>

          <%!-- Quantity + add to cart --%>
          <section class="mt-7 space-y-4 border-t border-[#E6D5B8] pt-6" aria-label="Add to cart">
            <div class="flex items-center gap-3">
              <span class="text-sm font-semibold uppercase tracking-[0.08em] text-[#2B1708]">
                Quantity
              </span>
              <div class="flex items-center border border-[#E6D5B8] bg-white">
                <button
                  phx-click="decrement_quantity"
                  disabled={@quantity <= 1}
                  class="flex h-10 w-10 cursor-pointer items-center justify-center text-[#2B1708] hover:bg-[#F0E3CE] disabled:cursor-not-allowed disabled:text-[#CFB183] motion-safe:transition-colors"
                  aria-label="Decrease quantity"
                >
                  <svg
                    class="h-4 w-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    stroke-linecap="round"
                    viewBox="0 0 16 16"
                    aria-hidden="true"
                  >
                    <path d="M4 8h8" />
                  </svg>
                </button>
                <div class="flex h-10 w-10 select-none items-center justify-center border-x border-[#E6D5B8] text-[0.9375rem] font-semibold tabular-nums text-[#2B1708]">
                  {@quantity}
                </div>
                <button
                  phx-click="increment_quantity"
                  disabled={@quantity >= 10}
                  class="flex h-10 w-10 cursor-pointer items-center justify-center text-[#2B1708] hover:bg-[#F0E3CE] disabled:cursor-not-allowed disabled:text-[#CFB183] motion-safe:transition-colors"
                  aria-label="Increase quantity"
                >
                  <svg
                    class="h-4 w-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    stroke-linecap="round"
                    viewBox="0 0 16 16"
                    aria-hidden="true"
                  >
                    <path d="M8 4v8M4 8h8" />
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
              :if={purchasable?(@selected_variant)}
              phx-click="add_to_cart"
              class="flex min-h-[54px] w-full cursor-pointer items-center justify-center gap-2.5 bg-store-accent px-8 text-sm font-bold uppercase tracking-[0.14em] text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.99]"
            >
              Add to cart
            </button>
            <button
              :if={!purchasable?(@selected_variant)}
              type="button"
              disabled
              aria-disabled="true"
              class="flex min-h-[54px] w-full cursor-not-allowed items-center justify-center bg-[#E6D5B8] px-8 text-sm font-bold uppercase tracking-[0.14em] text-[#A08863]"
            >
              Out of stock
            </button>

            <a
              :if={Shared.whatsapp_link(@store, @product.title)}
              href={Shared.whatsapp_link(@store, @product.title)}
              target="_blank"
              rel="noopener noreferrer"
              class="flex min-h-[48px] w-full items-center justify-center gap-2.5 border border-[#E6D5B8] bg-[#FFFBF2] text-sm font-semibold text-[#2B1708] hover:border-whatsapp hover:text-whatsapp focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] motion-safe:transition-colors"
            >
              <svg
                class="h-5 w-5 text-whatsapp"
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
              class="text-center text-xs text-[#A08863]"
            >
              SKU: {@selected_variant.sku}
            </p>
          </section>

          <%!-- Accordions — honest, merchant-owned policies only --%>
          <div class="mt-7 border-t border-[#E6D5B8]">
            <details class="group border-b border-[#E6D5B8]">
              <summary class="flex cursor-pointer select-none items-center justify-between py-4 text-sm font-semibold uppercase tracking-[0.08em] text-[#2B1708] hover:text-[#B97C10] motion-safe:transition-colors [&::-webkit-details-marker]:hidden">
                Details
                <svg
                  class="h-5 w-5 text-[#A08863] motion-safe:transition-transform motion-safe:duration-300 group-open:rotate-180"
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
              <div class="pb-5 text-sm leading-relaxed text-[#7A6248]">
                <p :if={@product.description}>{@product.description}</p>
                <p :if={!@product.description}>No additional details available.</p>
              </div>
            </details>
            <details class="group border-b border-[#E6D5B8]">
              <summary class="flex cursor-pointer select-none items-center justify-between py-4 text-sm font-semibold uppercase tracking-[0.08em] text-[#2B1708] hover:text-[#B97C10] motion-safe:transition-colors [&::-webkit-details-marker]:hidden">
                Delivery &amp; returns
                <svg
                  class="h-5 w-5 text-[#A08863] motion-safe:transition-transform motion-safe:duration-300 group-open:rotate-180"
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
              <div class="pb-5 text-sm leading-relaxed text-[#7A6248]">
                <p>
                  See
                  <a
                    href={store_path(@store.slug, "/policies")}
                    class="underline decoration-[#CFB183] underline-offset-2 hover:text-[#2B1708]"
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

      <%!-- Related pieces — browse-only cards (see @moduledoc) --%>
      <section
        :if={@related_products != []}
        class="border-t border-[#E6D5B8] bg-[#FFFBF2]"
        aria-labelledby="ntoma-related-heading"
      >
        <div class="mx-auto max-w-[1280px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
          <div class="mb-6 flex items-center justify-between gap-4">
            <h2
              id="ntoma-related-heading"
              class="text-2xl font-semibold uppercase tracking-tight text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-3xl"
            >
              You may also like
            </h2>
            <a
              href={store_path(@store.slug, "/products")}
              class="whitespace-nowrap text-sm font-semibold uppercase tracking-[0.1em] text-[#B97C10] hover:text-[#2B1708] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] motion-safe:transition-colors"
            >
              View all
            </a>
          </div>
          <div class="grid grid-cols-2 gap-x-3 gap-y-8 md:grid-cols-4 md:gap-x-5">
            <Shared.product_card
              :for={related <- Enum.take(@related_products, 4)}
              product={related}
              store={@store}
              show_add={false}
            />
          </div>
        </div>
      </section>

      <%!-- Customer reviews --%>
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

      <%!-- Mobile spacer clears the fixed bottom tab bar --%>
      <div class="h-16 sm:hidden"></div>
    </div>

    <Shared.footer store={@store} categories={@categories} />
    <Shared.ntoma_bottom_nav store={@store} cart_count={@cart_count} />
    """
  end

  defp purchasable?(nil), do: false
  defp purchasable?(variant), do: Emakola.Catalog.Variant.in_stock?(variant)

  attr :variant, :map, default: nil

  defp stock_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="inline-flex items-center gap-1.5 text-sm text-[#A08863]">
          Select options
        </span>
      <% @variant.track_inventory and @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-[#9E3B14]">
          <span class="h-2 w-2 rounded-full bg-[#9E3B14]"></span> Out of stock
        </span>
      <% @variant.track_inventory and @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-[#B97C10]">
          <span class="h-2 w-2 rounded-full bg-[#B97C10]"></span> Only {@variant.stock_quantity} left
        </span>
      <% true -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-[#3D6B35]">
          <span class="h-2 w-2 rounded-full bg-[#3D6B35]"></span> In stock
        </span>
    <% end %>
    """
  end
end
