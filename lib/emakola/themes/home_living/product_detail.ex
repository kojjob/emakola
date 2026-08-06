defmodule Emakola.Themes.HomeLiving.ProductDetail do
  @moduledoc """
  Home Living theme product detail — gallery + dimensions + materials
  + "Pair it with" complementary products section.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Delivery
  alias Emakola.Themes.HomeLiving.Shared
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
    <div class="home-living-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.home_living_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumbs --%>
      <div class="bg-[#FAF7F2] border-b border-[#E8DBC8]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <nav class="flex items-center gap-2 text-xs text-[#92400E]/60">
            <a href={store_path(@store.slug, "/")} class="hover:text-[#C2410C]">Home</a>
            <span>/</span>
            <a href={store_path(@store.slug, "/products")} class="hover:text-[#C2410C]">Shop</a>
            <span>/</span>
            <span class="text-[#3F2D1A] font-medium truncate max-w-[200px]">{@product.title}</span>
          </nav>
        </div>
      </div>

      <%!-- Main product --%>
      <section class="bg-[#FAF7F2] py-10 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16">
            <%!-- Gallery --%>
            <div>
              <div class="aspect-square home-living-card overflow-hidden">
                <.optimized_image
                  :if={Shared.current_image(@product, @current_image_index)}
                  src={Shared.current_image(@product, @current_image_index)}
                  alt={@product.title}
                  class="w-full h-full object-cover"
                />
                <div
                  :if={!Shared.current_image(@product, @current_image_index)}
                  class="w-full h-full flex items-center justify-center bg-gradient-to-br from-[#E8DBC8] to-[#FAF7F2]"
                >
                  <span class="material-symbols-outlined text-[#C2410C]/30" style="font-size: 120px;">
                    chair
                  </span>
                </div>
              </div>

              <div :if={length(@product.images) > 1} class="flex gap-3 mt-4 overflow-x-auto">
                <button
                  :for={{image, idx} <- Enum.with_index(@product.images)}
                  type="button"
                  phx-click="select_image"
                  phx-value-index={idx}
                  class={"flex-shrink-0 w-20 h-20 rounded-xl overflow-hidden bg-white border-2 transition-colors " <>
                    if(idx == @current_image_index,
                      do: "border-[#C2410C]",
                      else: "border-transparent hover:border-[#E8DBC8]"
                    )}
                >
                  <img
                    src={Map.get(image, :thumbnail_url) || Map.get(image, :url)}
                    alt={"#{@product.title} #{idx + 1}"}
                    class="w-full h-full object-cover"
                  />
                </button>
              </div>
            </div>

            <%!-- Info --%>
            <div>
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#65A30D]/15 text-[#65A30D] text-[11px] font-semibold uppercase tracking-[0.18em] mb-4">
                <span class="material-symbols-outlined" style="font-size: 14px;">eco</span>
                Crafted slowly
              </span>

              <h1 class="home-living-heading text-3xl sm:text-4xl lg:text-5xl font-medium text-[#3F2D1A] leading-tight mb-3">
                {@product.title}
              </h1>

              <Emakola.Themes.Shared.RealPhotoBadge.badge product={@product} />

              <%!-- Price + dimensions --%>
              <div class="flex items-baseline gap-4 mb-6 flex-wrap">
                <span class="home-living-heading text-3xl font-semibold text-[#C2410C]">
                  {EmakolaWeb.Helpers.Currency.format_price(
                    price_for(@product, @selected_variant),
                    Map.get(@store, :currency, "GHS")
                  )}
                </span>
                <span :if={dimensions(@product)} class="text-xs font-mono text-[#92400E]/70">
                  {dimensions(@product)}
                </span>
              </div>

              <%!-- Description --%>
              <p :if={@product.description} class="text-base text-[#3F2D1A]/80 leading-relaxed mb-6">
                {@product.description}
              </p>

              <%!-- Variant options --%>
              <div :if={@option_types != []} class="space-y-5 mb-6">
                <div :for={option_type <- @option_types}>
                  <p class="text-xs font-semibold uppercase tracking-wider text-[#3F2D1A] mb-2">
                    {option_type.name}
                  </p>
                  <div class="flex flex-wrap gap-2">
                    <button
                      :for={option_value <- option_type.option_values || []}
                      type="button"
                      phx-click="select_option"
                      phx-value-option_type_id={option_type.id}
                      phx-value-option_value_id={option_value.id}
                      class={"px-4 py-2.5 rounded-xl border-2 text-sm font-medium transition-colors min-h-[44px] " <>
                        if(Map.get(@selected_options, option_type.id) == option_value.id,
                          do: "bg-[#C2410C] text-white border-[#C2410C]",
                          else:
                            "bg-white text-[#3F2D1A] border-[#E8DBC8] hover:border-[#C2410C]"
                        )}
                    >
                      {option_value.value}
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Quantity + add to cart --%>
              <div class="flex flex-col sm:flex-row items-stretch gap-3 mb-7">
                <div class="flex items-center gap-2 px-3 py-2 bg-white rounded-xl border border-[#E8DBC8]">
                  <button
                    type="button"
                    phx-click="decrement_quantity"
                    class="w-9 h-9 rounded-lg hover:bg-[#FAF7F2] flex items-center justify-center"
                    aria-label="Decrease"
                  >
                    <span class="material-symbols-outlined text-[#3F2D1A]" style="font-size: 18px;">
                      remove
                    </span>
                  </button>
                  <span class="w-10 text-center text-base font-bold text-[#3F2D1A]">
                    {@quantity}
                  </span>
                  <button
                    type="button"
                    phx-click="increment_quantity"
                    class="w-9 h-9 rounded-lg hover:bg-[#FAF7F2] flex items-center justify-center"
                    aria-label="Increase"
                  >
                    <span class="material-symbols-outlined text-[#3F2D1A]" style="font-size: 18px;">
                      add
                    </span>
                  </button>
                </div>
                <button
                  type="button"
                  phx-click="add_to_cart"
                  class="flex-1 inline-flex items-center justify-center gap-2 px-7 py-4 rounded-xl bg-[#C2410C] text-white text-sm font-semibold hover:bg-[#9A340A] transition-colors min-h-[48px]"
                >
                  <span class="material-symbols-outlined" style="font-size: 18px;">shopping_bag</span>
                  Add to Cart
                </button>
              </div>

              <%!-- Trust strip. A "Quality materials" tile led this on every
                   product; the platform has no materials field and no idea what
                   the thing is made of. Secure payment is true of every store
                   here, which is what makes it worth saying. --%>
              <div class="grid grid-cols-3 gap-3 pt-6 border-t border-[#E8DBC8]">
                <div class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#65A30D] mb-1" style="font-size: 22px;">
                    lock
                  </span>
                  <p class="text-[10px] uppercase tracking-wider font-semibold text-[#3F2D1A]">
                    Secure payment
                  </p>
                </div>
                <%!-- "5-day shipping" and "30-day returns" used to sit here on
                     every Home Living product, for every store, set by nobody.
                     Delivery is the store's own now, and so is the returns
                     window below — a merchant who has stated none gets the plain
                     link to their policies page instead of an invented number. --%>
                <div :if={Delivery.callout(assigns)} class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#65A30D] mb-1" style="font-size: 22px;">
                    local_shipping
                  </span>
                  <p class="text-[10px] uppercase tracking-wider font-semibold text-[#3F2D1A]">
                    {Delivery.callout(assigns)}
                  </p>
                </div>
                <div class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#65A30D] mb-1" style="font-size: 22px;">
                    swap_horiz
                  </span>
                  <a
                    href={store_path(@store.slug, "/policies#returns")}
                    class="text-[10px] uppercase tracking-wider font-semibold text-[#3F2D1A] underline decoration-[#A8A29E] underline-offset-2 hover:text-[#65A30D] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#65A30D] rounded"
                  >
                    {Terms.returns(Terms.content(assigns)) || "Returns policy"}
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Pair it with --%>
      <section :if={@related_products != []} class="bg-white py-14 sm:py-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="home-living-heading text-3xl sm:text-4xl font-medium text-[#3F2D1A] mb-8">
            Pair it with
          </h2>
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

      <Shared.home_living_footer store={@store} />
    </div>
    """
  end

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0

  defp dimensions(product) do
    case Map.get(product, :dimensions) do
      d when is_binary(d) and d != "" -> d
      _ -> nil
    end
  end
end
