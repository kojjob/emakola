defmodule Emakola.Themes.Fashion.ProductDetail do
  @moduledoc """
  Fashion theme product detail — editorial gallery + Playfair title
  + sticky size guide + aubergine "Add to Bag" CTA.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  alias Emakola.Themes.Gallery

  alias Emakola.Themes.Delivery
  alias Emakola.Themes.Fashion.Shared
  alias Emakola.Themes.Terms

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :product, :map, required: true
  attr :related_products, :list, default: []
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :selected_variant, :map, default: nil
  attr :option_types, :list, default: []
  attr :selected_options, :map, default: %{}
  attr :quantity, :integer, default: 1
  attr :current_image_index, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="fashion-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.fashion_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumbs --%>
      <div class="bg-[#FAF6EE] border-b border-[#E7E5E4]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <nav class="flex items-center gap-2 text-[10px] uppercase tracking-[0.18em] text-[#57534E]">
            <a href={store_path(@store.slug, "/")} class="hover:text-[#5B21B6]">Home</a>
            <span>/</span>
            <a href={store_path(@store.slug, "/products")} class="hover:text-[#5B21B6]">Shop</a>
            <span>/</span>
            <span class="text-[#1C1917] font-semibold truncate max-w-[200px] normal-case tracking-normal">
              {@product.title}
            </span>
          </nav>
        </div>
      </div>

      <%!-- Main product --%>
      <section class="bg-[#FAF6EE] py-10 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16">
            <Gallery.product_gallery
              images={@product.images}
              current_index={@current_image_index}
              alt={@product.title}
              aspect_class="aspect-[3/4]"
              frame_class="bg-white"
              thumb_class="h-20 w-[60px]"
              thumb_active_class="border-[#5B21B6]"
              thumb_idle_class="border-transparent hover:border-[#E7E5E4]"
              rail_class="sm:w-[60px]"
            >
              <:placeholder>
                <span class="material-symbols-outlined text-[#5B21B6]/30" style="font-size: 140px;">
                  checkroom
                </span>
              </:placeholder>
            </Gallery.product_gallery>

            <%!-- Info --%>
            <div class="lg:sticky lg:top-24 lg:self-start">
              <h1 class="fashion-display text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-[1.05] mb-4">
                {@product.title}
              </h1>

              <Emakola.Themes.Shared.RealPhotoBadge.badge product={@product} />

              <%!-- Price --%>
              <p class="fashion-heading text-2xl sm:text-3xl font-semibold text-[var(--theme-primary,#5B21B6)] mb-6">
                {EmakolaWeb.Helpers.Currency.format_price(
                  price_for(@product, @selected_variant),
                  Map.get(@store, :currency, "GHS")
                )}
              </p>

              <%!-- Description --%>
              <p
                :if={@product.description}
                class="text-base text-[#57534E] leading-relaxed mb-7 italic fashion-heading"
              >
                {@product.description}
              </p>

              <%!-- Variant options --%>
              <div :if={@option_types != []} class="space-y-5 mb-6">
                <div :for={option_type <- @option_types}>
                  <div class="flex items-center justify-between mb-2">
                    <p class="text-[11px] font-bold uppercase tracking-[0.18em] text-[#1C1917]">
                      {option_type.name}
                    </p>
                    <button
                      :if={String.downcase(to_string(option_type.name)) == "size"}
                      type="button"
                      class="text-[11px] uppercase tracking-[0.18em] text-[#5B21B6] hover:underline"
                    >
                      Size guide
                    </button>
                  </div>
                  <div class="flex flex-wrap gap-2">
                    <button
                      :for={option_value <- option_type.option_values || []}
                      type="button"
                      phx-click="select_option"
                      phx-value-option_type_id={option_type.id}
                      phx-value-option_value_id={option_value.id}
                      class={"px-4 py-2.5 border text-sm font-medium uppercase tracking-wider transition-colors min-h-[44px] " <>
                        if(Map.get(@selected_options, option_type.id) == option_value.id,
                          do: "bg-[#1C1917] text-white border-[#1C1917]",
                          else:
                            "bg-white text-[#1C1917] border-[#E7E5E4] hover:border-[#1C1917]"
                        )}
                    >
                      {option_value.value}
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Quantity + add to bag --%>
              <div class="flex flex-col sm:flex-row items-stretch gap-3 mb-7">
                <div class="flex items-center gap-2 px-3 py-2 bg-white rounded-full border border-[#E7E5E4]">
                  <button
                    type="button"
                    phx-click="decrement_quantity"
                    class="w-9 h-9 rounded-full hover:bg-[#FAF6EE] flex items-center justify-center"
                    aria-label="Decrease"
                  >
                    <span class="material-symbols-outlined text-[#1C1917]" style="font-size: 18px;">
                      remove
                    </span>
                  </button>
                  <span class="w-10 text-center text-base font-bold text-[#1C1917]">
                    {@quantity}
                  </span>
                  <button
                    type="button"
                    phx-click="increment_quantity"
                    class="w-9 h-9 rounded-full hover:bg-[#FAF6EE] flex items-center justify-center"
                    aria-label="Increase"
                  >
                    <span class="material-symbols-outlined text-[#1C1917]" style="font-size: 18px;">
                      add
                    </span>
                  </button>
                </div>
                <button
                  type="button"
                  phx-click="add_to_cart"
                  class="flex-1 inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-[var(--theme-primary,#5B21B6)] text-white text-xs font-bold uppercase tracking-[0.18em] hover:bg-[#4C1D95] transition-colors min-h-[48px]"
                >
                  <span class="material-symbols-outlined" style="font-size: 18px;">shopping_bag</span>
                  Add to Bag
                </button>
              </div>

              <%!-- Trust strip. Two of these three tiles used to read "Free over
                   GHS 500" and "14-day returns" — a threshold and a returns
                   window no Fashion merchant had set, on every product they
                   sold. Delivery now states the store's own zones (nothing when
                   it has configured none) and the returns tile states the
                   merchant's own window, falling back to a plain link to their
                   policies page when they have stated none. --%>
              <%!-- A "Hand-sewn" tile used to sit here on every Fashion product,
                   including the ones that were not. Whether a garment was sewn by
                   hand is a fact about the garment; the platform has no field for
                   it and no way to know. Secure payment is true of every store on
                   the platform, so it is the honest thing to put in its place. --%>
              <div class="grid grid-cols-3 gap-3 pt-7 border-t border-[#E7E5E4]">
                <div class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#5B21B6] mb-1" style="font-size: 22px;">
                    lock
                  </span>
                  <p class="text-[10px] uppercase tracking-[0.18em] font-semibold text-[#1C1917]">
                    Secure payment
                  </p>
                </div>
                <div :if={Delivery.callout(assigns)} class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#5B21B6] mb-1" style="font-size: 22px;">
                    local_shipping
                  </span>
                  <p class="text-[10px] uppercase tracking-[0.18em] font-semibold text-[#1C1917]">
                    {Delivery.callout(assigns)}
                  </p>
                </div>
                <div class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#5B21B6] mb-1" style="font-size: 22px;">
                    swap_horiz
                  </span>
                  <a
                    href={store_path(@store.slug, "/policies#returns")}
                    class="text-[10px] uppercase tracking-[0.18em] font-semibold text-[#1C1917] underline decoration-[#A8A29E] underline-offset-2 hover:text-[#5B21B6] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5B21B6] rounded"
                  >
                    {Terms.returns(Terms.content(assigns)) || "Returns policy"}
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Related --%>
      <section :if={@related_products != []} class="bg-[#FAF6EE] pb-14 sm:pb-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-10">
            <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-2">
              More from the edit
            </p>
            <h2 class="fashion-display text-3xl sm:text-4xl text-[#1C1917]">
              You may also love.
            </h2>
          </div>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
            <Shared.product_card
              :for={product <- Enum.take(@related_products, 4)}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

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

      <Shared.fashion_footer store={@store} />
    </div>
    """
  end

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0
end
