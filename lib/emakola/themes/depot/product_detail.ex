defmodule Emakola.Themes.Depot.ProductDetail do
  @moduledoc """
  Depot theme — product detail as a spec sheet.

  A trade buyer wants the facts: price per unit, stock on hand, SKU, unit
  weight, then a quantity and an add button. Photography is optional and
  the page looks finished without it. The spec list shows only fields the
  variant really carries (`sku`, `weight_grams`, stock) — the catalog has
  no minimum-order or tier fields, so none are shown. Reviews and other
  social proof are deliberately absent: trust here is commercial.

  Wires only the detail LiveView's real handlers: `select_option`,
  `select_image`, `increment_quantity` / `decrement_quantity` (clamped
  1..10 server-side), and `add_to_cart`.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Depot.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAF9F7]">
      <Shared.depot_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <nav
        class="mx-auto hidden max-w-[1120px] px-4 py-4 sm:px-6 lg:block lg:px-8"
        aria-label="Breadcrumb"
      >
        <ol class="flex items-center gap-2 font-mono text-xs text-zinc-500">
          <li>
            <a
              href={store_path(@store.slug, "/")}
              class="hover:text-zinc-900 motion-safe:transition-colors"
            >
              {@store.name}
            </a>
          </li>
          <li aria-hidden="true">/</li>
          <li>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-zinc-900 motion-safe:transition-colors"
            >
              Catalogue
            </a>
          </li>
          <li aria-hidden="true">/</li>
          <li class="max-w-[240px] truncate text-zinc-900">{@product.title}</li>
        </ol>
      </nav>

      <div class="mx-auto max-w-[1120px] px-4 py-6 sm:px-6 lg:px-8 lg:pb-10 lg:pt-2">
        <div class="lg:grid lg:grid-cols-2 lg:gap-10">
          <%!-- Image column — placeholder-first, finished without a photo --%>
          <div class="lg:sticky lg:top-24 lg:self-start">
            <div class="relative aspect-[4/5] overflow-hidden border border-[#E7E5E1] shadow-sm bg-white">
              <div
                class="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-zinc-100 to-zinc-200"
                aria-hidden="true"
              >
                <span class="select-none text-8xl font-bold text-zinc-400 [font-family:var(--dt-heading-font,inherit)]">
                  {String.first(@product.title)}
                </span>
              </div>
              <.optimized_image
                :if={Shared.current_image(@product, @current_image_index)}
                src={Shared.current_image(@product, @current_image_index)}
                alt={@product.title}
                priority={:high}
                width={640}
                height={640}
                class="absolute inset-0 h-full w-full object-cover"
              />
            </div>

            <div :if={length(@product.images) > 1} class="mt-2.5 grid grid-cols-5 gap-2">
              <button
                :for={{_image, idx} <- Enum.with_index(@product.images)}
                phx-click="select_image"
                phx-value-index={idx}
                aria-label={"View image #{idx + 1}"}
                class={[
                  "aspect-square cursor-pointer overflow-hidden border-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 motion-safe:transition-colors",
                  if(idx == @current_image_index,
                    do: "border-zinc-900",
                    else: "border-[#E7E5E1] opacity-70 hover:border-zinc-400 hover:opacity-100"
                  )
                ]}
              >
                <.optimized_image
                  src={Shared.current_image(@product, idx)}
                  alt={"#{@product.title} thumbnail #{idx + 1}"}
                  priority={:low}
                  width={96}
                  height={96}
                  class="h-full w-full object-cover"
                />
              </button>
            </div>
          </div>

          <%!-- Spec column --%>
          <div class="mt-6 lg:mt-0">
            <p class="font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-zinc-500">
              {@store.name}
            </p>
            <h1 class="mt-1.5 text-2xl font-bold leading-tight tracking-tight text-zinc-900 [font-family:var(--dt-heading-font,inherit)] sm:text-3xl">
              {@product.title}
            </h1>

            <Emakola.Themes.Shared.RealPhotoBadge.badge product={@product} />

            <div class="mt-3 flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
              <p class="text-2xl font-bold tabular-nums text-zinc-900 sm:text-[1.75rem]">
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
              <%= if @selected_variant && is_integer(@selected_variant.compare_at_price) && @selected_variant.compare_at_price > @selected_variant.price do %>
                <s class="text-base tabular-nums text-zinc-400 line-through">
                  <span class="sr-only">was</span>
                  {Currency.format_price(@selected_variant.compare_at_price, @store.currency)}
                </s>
              <% end %>
            </div>

            <%!-- Spec list: only fields the variant really carries --%>
            <dl class="mt-5 divide-y divide-zinc-200 border-y-2 border-zinc-900">
              <div
                :if={@selected_variant && @selected_variant.sku}
                class="flex items-center justify-between gap-4 py-2.5"
              >
                <dt class="font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-zinc-500">
                  SKU
                </dt>
                <dd class="font-mono text-sm text-zinc-900">{@selected_variant.sku}</dd>
              </div>
              <div
                :if={Shared.format_weight(@selected_variant)}
                class="flex items-center justify-between gap-4 py-2.5"
              >
                <dt class="font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-zinc-500">
                  Unit weight
                </dt>
                <dd class="text-sm tabular-nums text-zinc-900">
                  {Shared.format_weight(@selected_variant)}
                </dd>
              </div>
              <div class="flex items-center justify-between gap-4 py-2.5">
                <dt class="font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.14em] text-zinc-500">
                  Availability
                </dt>
                <dd>
                  <%= if @selected_variant do %>
                    <Shared.stock_indicator variant={@selected_variant} />
                  <% else %>
                    <span class="text-xs font-semibold text-zinc-500">Select options</span>
                  <% end %>
                </dd>
              </div>
            </dl>

            <%!-- Variant selectors --%>
            <section :if={@option_types != []} class="mt-5 space-y-4" aria-label="Product options">
              <div :for={option_type <- @option_types}>
                <p class="mb-2 text-sm font-semibold text-zinc-900">{option_type.name}</p>
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
                    aria-checked={Map.get(@selected_options, option_type.id) == option_value.id}
                    class={[
                      "min-w-[52px] cursor-pointer border-2 px-4 py-2.5 text-sm font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do: "border-zinc-900 bg-zinc-900 text-white",
                        else: "border-zinc-300 bg-white text-zinc-900 hover:border-zinc-900"
                      )
                    ]}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </section>

            <%!-- Quantity + add to order --%>
            <section class="mt-6 space-y-4" aria-label="Add to order">
              <div class="flex items-center justify-between gap-4">
                <div class="flex items-center gap-3">
                  <span class="text-sm font-semibold text-zinc-900">Quantity</span>
                  <div class="flex items-center border border-[#E7E5E1] shadow-sm bg-white">
                    <button
                      phx-click="decrement_quantity"
                      disabled={@quantity <= 1}
                      aria-label="Decrease quantity"
                      class="flex h-11 w-11 cursor-pointer items-center justify-center text-zinc-900 hover:bg-zinc-100 disabled:cursor-not-allowed disabled:text-zinc-300 motion-safe:transition-colors"
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
                    <span class="flex h-11 w-11 select-none items-center justify-center border-x-2 border-zinc-900 text-[0.9375rem] font-bold tabular-nums text-zinc-900">
                      {@quantity}
                    </span>
                    <button
                      phx-click="increment_quantity"
                      disabled={@quantity >= 10}
                      aria-label="Increase quantity"
                      class="flex h-11 w-11 cursor-pointer items-center justify-center text-zinc-900 hover:bg-zinc-100 disabled:cursor-not-allowed disabled:text-zinc-300 motion-safe:transition-colors"
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
                <div :if={@selected_variant} class="text-right">
                  <p class="font-mono text-[0.625rem] font-semibold uppercase tracking-[0.14em] text-zinc-500">
                    Line total
                  </p>
                  <p class="text-base font-bold tabular-nums text-zinc-900">
                    {Currency.format_price(@selected_variant.price * @quantity, @store.currency)}
                  </p>
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
                phx-click="add_to_cart"
                disabled={
                  is_nil(@selected_variant) ||
                    not Emakola.Catalog.Variant.in_stock?(@selected_variant)
                }
                class={[
                  "flex h-[54px] w-full items-center justify-center gap-2.5 text-base font-bold motion-safe:transition-colors",
                  if(
                    is_nil(@selected_variant) ||
                      not Emakola.Catalog.Variant.in_stock?(@selected_variant),
                    do: "cursor-not-allowed bg-zinc-200 text-zinc-400",
                    else:
                      "cursor-pointer bg-store-accent text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:active:scale-[0.99]"
                  )
                ]}
              >
                <%= if is_nil(@selected_variant) || not Emakola.Catalog.Variant.in_stock?(@selected_variant) do %>
                  Out of stock
                <% else %>
                  Add to order
                <% end %>
              </button>

              <a
                :if={Shared.whatsapp_link(@store, @product.title)}
                href={Shared.whatsapp_link(@store, @product.title)}
                target="_blank"
                rel="noopener noreferrer"
                class="flex h-12 w-full items-center justify-center gap-2.5 border-2 border-zinc-300 text-[0.9375rem] font-semibold text-zinc-900 hover:border-whatsapp hover:text-whatsapp focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 motion-safe:transition-colors"
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
                Discuss a larger order on WhatsApp
              </a>
            </section>

            <%!-- Details --%>
            <section :if={@product.description} class="mt-7" aria-labelledby="depot-details-heading">
              <h2
                id="depot-details-heading"
                class="mb-2 font-mono text-xs font-semibold uppercase tracking-[0.16em] text-zinc-500"
              >
                Details
              </h2>
              <p class="text-sm leading-relaxed text-zinc-700">{@product.description}</p>
            </section>

            <p class="mt-7 border-t border-[#E7E5E1] pt-4 text-xs text-zinc-500">
              Delivery &amp; returns —
              <a
                href={store_path(@store.slug, "/policies#shipping")}
                class="font-medium underline decoration-zinc-300 underline-offset-2 hover:text-zinc-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900"
              >
                see this store's policies
              </a>
            </p>
          </div>
        </div>

        <%!-- Related items, set as compact ledger rows --%>
        <section
          :if={@related_products != []}
          class="mt-10"
          aria-labelledby="depot-related-heading"
        >
          <h2
            id="depot-related-heading"
            class="mb-3 font-mono text-xs font-semibold uppercase tracking-[0.16em] text-zinc-500"
          >
            Also stocked
          </h2>
          <ul class="divide-y divide-zinc-200 border border-[#E7E5E1] shadow-sm bg-white">
            <li :for={related <- @related_products}>
              <a
                href={store_path(@store.slug, "/products/#{related.slug}")}
                class="flex items-center justify-between gap-4 px-4 py-3 hover:bg-[#FAF9F7] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-zinc-900 motion-safe:transition-colors sm:px-5"
              >
                <span class="min-w-0 truncate text-sm font-semibold text-zinc-900">
                  {related.title}
                </span>
                <span class="flex-shrink-0 text-sm font-bold tabular-nums text-zinc-900">
                  {Currency.format_price_range(related.min_price, related.max_price, @store.currency)}
                </span>
              </a>
            </li>
          </ul>
        </section>
      </div>
    </div>

    <%!-- Guarded and defaulted: this module is also rendered by
         component tests that build assigns without the review keys,
         where reading @reviews would raise. --%>
    <EmakolaWeb.ReviewComponents.review_section
      :if={assigns[:reviews] != nil}
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
      review_count={Map.get(@product, :review_count, 0)}
      uploads={assigns[:uploads]}
    />

    <Shared.footer store={@store} categories={@categories} />
    <Shared.depot_bottom_nav store={@store} cart_count={@cart_count} active={:catalogue} />
    """
  end
end
