defmodule Emakola.Themes.Pace.ProductDetail do
  @moduledoc """
  Pace theme — product detail page.

  The ice ground and rounded canvas carry over: night-gradient image
  stage (ghost initial before the photo arrives), thumbnail selection
  (`select_image`), variant lane pills (`select_option`), quantity
  stepper, add-to-cart, WhatsApp ask link, policy accordions that defer
  to the store's own policies (no invented SLAs), a related-products
  rail, and the shared customer reviews section.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Pace.Shared
  alias Emakola.Themes.Terms
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[var(--theme-bg,#E6EFF6)] pt-2">
      <Shared.theme_styles theme={@theme} />
      <Shared.pace_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />

      <div class="px-2 pt-3 sm:px-4 lg:px-6">
        <div class="mx-auto max-w-[1440px] rounded-[28px] bg-white pb-16 sm:rounded-[36px]">
          <div class="mx-auto max-w-[1280px] px-5 sm:px-8 lg:px-10">
            <nav aria-label="Breadcrumb" class="pt-6">
              <ol class="flex items-center gap-2 text-xs font-medium tracking-wide text-slate-500">
                <li>
                  <a
                    href={store_path(@store.slug, "/")}
                    class="rounded hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 motion-safe:transition-colors"
                  >
                    Home
                  </a>
                </li>
                <li aria-hidden="true" class="pace-display italic text-slate-300">///</li>
                <li>
                  <a
                    href={store_path(@store.slug, "/products")}
                    class="rounded hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 motion-safe:transition-colors"
                  >
                    Shop
                  </a>
                </li>
                <li aria-hidden="true" class="pace-display italic text-slate-300">///</li>
                <li class="max-w-[200px] truncate text-slate-950">{@product.title}</li>
              </ol>
            </nav>

            <div class="gap-10 py-6 lg:grid lg:grid-cols-2 lg:gap-12 lg:py-8">
              <%!-- Image stage --%>
              <div class="lg:sticky lg:top-24 lg:self-start">
                <div class="relative aspect-[4/5] overflow-hidden rounded-[24px] bg-gradient-to-b from-slate-800 to-slate-950 lg:aspect-[3/4]">
                  <span
                    class="pace-display absolute inset-0 flex select-none items-center justify-center text-9xl font-bold italic text-white/10"
                    aria-hidden="true"
                  >
                    {String.first(@product.title)}
                  </span>
                  <.optimized_image
                    :if={Shared.current_image(@product, @current_image_index)}
                    src={Shared.current_image(@product, @current_image_index)}
                    alt={"#{@product.title} — image #{@current_image_index + 1}"}
                    priority={:high}
                    class="absolute inset-0 h-full w-full object-cover"
                  />
                </div>

                <div
                  :if={length(@product.images) > 1}
                  class="mt-3 grid grid-cols-4 gap-2.5"
                  role="tablist"
                  aria-label="Product images"
                >
                  <button
                    :for={{_img, idx} <- Enum.with_index(@product.images)}
                    phx-click="select_image"
                    phx-value-index={idx}
                    role="tab"
                    aria-selected={to_string(idx == @current_image_index)}
                    aria-label={"View image #{idx + 1}"}
                    class={[
                      "aspect-square cursor-pointer overflow-hidden rounded-2xl border-2 bg-slate-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-opacity",
                      if(idx == @current_image_index,
                        do: "border-slate-950 opacity-100",
                        else: "border-transparent opacity-70 hover:opacity-100"
                      )
                    ]}
                  >
                    <.optimized_image
                      :if={Shared.current_image(@product, idx)}
                      src={Shared.current_image(@product, idx)}
                      alt=""
                      priority={:low}
                      class="h-full w-full object-cover"
                    />
                  </button>
                </div>
              </div>

              <%!-- Product info --%>
              <div class="pt-6 lg:pt-0">
                <p class="mb-3 text-[0.6875rem] font-bold uppercase tracking-[0.18em] text-slate-500">
                  <span aria-hidden="true">///</span> {@store.name}
                </p>
                <h1 class="pace-display text-3xl font-bold uppercase italic leading-tight tracking-tight text-slate-950 sm:text-4xl">
                  {@product.title}
                </h1>

                <div class="mt-3 flex items-baseline gap-2.5">
                  <p class="pace-display text-2xl font-bold tabular-nums text-slate-950 sm:text-[1.75rem]">
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
                    class="text-base tabular-nums text-slate-400 line-through"
                  >
                    {Currency.format_price(@selected_variant.compare_at_price, @store.currency)}
                  </p>
                </div>

                <div class="mt-3">
                  <.stock_line variant={@selected_variant} />
                </div>

                <p
                  :if={@product.description}
                  class="mt-4 text-[0.9375rem] leading-relaxed text-slate-600"
                >
                  {@product.description}
                </p>

                <%!-- Variant selectors --%>
                <div :if={@option_types != []} class="mt-6 space-y-5" aria-label="Product options">
                  <div :for={ot <- @option_types}>
                    <div class="mb-3 text-sm font-semibold text-slate-950">{ot.name}</div>
                    <div
                      class="flex flex-wrap gap-2.5"
                      role="radiogroup"
                      aria-label={"Select #{ot.name}"}
                    >
                      <button
                        :for={ov <- ot.option_values}
                        phx-click="select_option"
                        phx-value-option_type_id={ot.id}
                        phx-value-value={ov.id}
                        role="radio"
                        aria-checked={to_string(Map.get(@selected_options, ot.id) == ov.id)}
                        class={[
                          "flex h-11 min-w-[52px] cursor-pointer items-center justify-center rounded-full px-5 text-sm font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
                          if(Map.get(@selected_options, ot.id) == ov.id,
                            do: "bg-slate-950 text-white",
                            else:
                              "border border-slate-200 bg-white text-slate-950 hover:border-slate-950"
                          )
                        ]}
                      >
                        {ov.value}
                      </button>
                    </div>
                  </div>
                </div>

                <%!-- Quantity + add to cart --%>
                <div class="mt-6 space-y-4">
                  <div class="flex items-center gap-3">
                    <span class="text-sm font-semibold text-slate-950">Quantity</span>
                    <div class="flex items-center overflow-hidden rounded-full border border-slate-200 bg-white">
                      <button
                        phx-click="decrement_quantity"
                        disabled={@quantity <= 1}
                        class="flex h-11 w-11 cursor-pointer items-center justify-center text-slate-950 hover:bg-[#F1F6FA] disabled:cursor-not-allowed disabled:text-slate-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 motion-safe:transition-colors"
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
                      <div class="flex h-11 w-11 select-none items-center justify-center border-x border-slate-200 text-[0.9375rem] font-semibold tabular-nums text-slate-950">
                        {@quantity}
                      </div>
                      <button
                        phx-click="increment_quantity"
                        disabled={@quantity >= 10}
                        class="flex h-11 w-11 cursor-pointer items-center justify-center text-slate-950 hover:bg-[#F1F6FA] disabled:cursor-not-allowed disabled:text-slate-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 motion-safe:transition-colors"
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

                  <button
                    id="pace-add-to-cart"
                    phx-click="add_to_cart"
                    disabled={!purchasable?(@selected_variant)}
                    class={[
                      "flex h-[54px] w-full items-center justify-center gap-2.5 rounded-full text-base font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-opacity",
                      if(purchasable?(@selected_variant),
                        do:
                          "cursor-pointer bg-store-accent text-white hover:opacity-90 motion-safe:active:scale-[0.99]",
                        else: "cursor-not-allowed bg-slate-200 text-slate-400"
                      )
                    ]}
                  >
                    <%= if purchasable?(@selected_variant) do %>
                      Add to cart
                      <span class="pace-display text-xs italic" aria-hidden="true">///</span>
                    <% else %>
                      Out of stock
                    <% end %>
                  </button>

                  <a
                    :if={Shared.whatsapp_link(@store, @product.title)}
                    href={Shared.whatsapp_link(@store, @product.title)}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="flex h-12 w-full items-center justify-center gap-2.5 rounded-full border border-slate-200 text-[0.9375rem] font-medium text-slate-950 hover:border-whatsapp hover:text-whatsapp focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
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
                    class="pt-0.5 text-center text-xs text-slate-400"
                  >
                    SKU: {@selected_variant.sku}
                  </p>
                </div>

                <%!-- Policies: defer to the store's own pages, never an invented SLA --%>
                <div class="mt-8 divide-y divide-slate-200 border-y border-slate-200">
                  <details class="group">
                    <summary class="flex cursor-pointer list-none items-center justify-between py-4 text-[0.9375rem] font-semibold text-slate-950 select-none [&::-webkit-details-marker]:hidden">
                      Shipping &amp; delivery
                      <span
                        class="pace-display text-xs italic text-slate-400 motion-safe:transition-transform motion-safe:group-open:rotate-90"
                        aria-hidden="true"
                      >
                        ///
                      </span>
                    </summary>
                    <p class="pb-5 text-sm leading-relaxed text-slate-600">
                      See the
                      <a
                        href={store_path(@store.slug, "/policies#shipping")}
                        class="rounded underline decoration-slate-300 underline-offset-2 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900"
                      >
                        delivery information
                      </a>
                      on this store's policies page.
                    </p>
                  </details>
                  <details class="group">
                    <summary class="flex cursor-pointer list-none items-center justify-between py-4 text-[0.9375rem] font-semibold text-slate-950 select-none [&::-webkit-details-marker]:hidden">
                      Returns &amp; exchange
                      <span
                        class="pace-display text-xs italic text-slate-400 motion-safe:transition-transform motion-safe:group-open:rotate-90"
                        aria-hidden="true"
                      >
                        ///
                      </span>
                    </summary>
                    <p class="pb-5 text-sm leading-relaxed text-slate-600">
                      <%!-- The merchant's own terms, when they have stated any.
                           The policies page stays the authority either way. --%>
                      <span
                        :if={Terms.badges(assigns) != []}
                        class="mb-1 block font-semibold text-slate-950"
                      >
                        {Enum.join(Terms.badges(assigns), " · ")}
                      </span>
                      See the
                      <a
                        href={store_path(@store.slug, "/policies")}
                        class="rounded underline decoration-slate-300 underline-offset-2 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900"
                      >
                        returns policy
                      </a>
                      on this store's policies page.
                    </p>
                  </details>
                </div>
              </div>
            </div>

            <%!-- Related products --%>
            <section
              :if={@related_products != []}
              class="pt-10"
              aria-labelledby="pace-related-heading"
            >
              <div class="mb-5 flex items-center justify-between">
                <h2
                  id="pace-related-heading"
                  class="pace-display text-xl font-bold uppercase italic tracking-tight text-slate-950"
                >
                  Keep moving
                </h2>
                <a
                  href={store_path(@store.slug, "/products")}
                  class="rounded text-sm font-semibold text-slate-600 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 motion-safe:transition-colors"
                >
                  View all
                </a>
              </div>
              <div class="flex snap-x snap-mandatory gap-3.5 overflow-x-auto pb-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden lg:grid lg:grid-cols-4 lg:gap-5">
                <a
                  :for={rp <- Enum.take(@related_products, 4)}
                  href={store_path(@store.slug, "/products/#{rp.slug}")}
                  class="group flex-[0_0_160px] snap-start rounded-[20px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 lg:flex-auto"
                >
                  <div class="relative aspect-[3/4] overflow-hidden rounded-[20px] bg-gradient-to-b from-slate-800 to-slate-950">
                    <span
                      class="pace-display absolute inset-0 flex select-none items-center justify-center text-6xl font-bold italic text-white/10"
                      aria-hidden="true"
                    >
                      {String.first(rp.title)}
                    </span>
                    <.optimized_image
                      :if={Shared.first_image(rp)}
                      src={Shared.first_image(rp)}
                      alt={rp.title}
                      class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-500 motion-safe:group-hover:scale-105"
                    />
                    <div
                      class="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-slate-950/10 to-transparent"
                      aria-hidden="true"
                    >
                    </div>
                    <span class="pace-display absolute bottom-2.5 left-2.5 z-10 inline-block rounded-full bg-white px-3 py-1.5 text-[0.8125rem] font-bold leading-none tabular-nums text-slate-950">
                      {Currency.format_price_range(rp.min_price, rp.max_price, @store.currency)}
                    </span>
                  </div>
                  <p class="mt-2.5 truncate text-sm font-semibold text-slate-950">{rp.title}</p>
                </a>
              </div>
            </section>

            <%!-- Customer reviews (shared platform component) --%>
            <EmakolaWeb.ReviewComponents.review_section
              store={@store}
              product={@product}
              reviews={@reviews}
              can_review={@can_review}
              already_reviewed={@already_reviewed}
              review_form_rating={@review_form_rating}
              review_form_title={@review_form_title}
              review_form_body={@review_form_body}
              review_submitting={@review_submitting}
              avg_rating={Map.get(@product, :avg_rating)}
              review_count={Map.get(@product, :review_count) || 0}
              uploads={assigns[:uploads]}
            />
          </div>
        </div>
      </div>

      <Shared.footer store={@store} categories={@categories} theme={assigns[:theme] || %{}} />
    </div>

    <Shared.pace_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} />
    """
  end

  defp purchasable?(nil), do: false
  defp purchasable?(variant), do: Emakola.Catalog.Variant.in_stock?(variant)

  attr :variant, :map, default: nil

  defp stock_line(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="inline-flex items-center gap-1.5 text-sm text-slate-400">Select options</span>
      <% @variant.track_inventory and @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-red-600">
          <span class="h-2 w-2 rounded-full bg-red-500" aria-hidden="true"></span> Out of stock
        </span>
      <% @variant.track_inventory and @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-amber-600">
          <span class="h-2 w-2 rounded-full bg-amber-500" aria-hidden="true"></span>
          Only {@variant.stock_quantity} left
        </span>
      <% true -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-600">
          <span class="h-2 w-2 rounded-full bg-emerald-500" aria-hidden="true"></span> In stock
        </span>
    <% end %>
    """
  end
end
