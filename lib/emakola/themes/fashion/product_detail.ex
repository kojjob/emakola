defmodule Emakola.Themes.Fashion.ProductDetail do
  @moduledoc """
  Fashion theme product detail — editorial gallery + Playfair title
  + sticky size guide + aubergine "Add to Bag" CTA.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Fashion.Shared

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
            <%!-- Gallery --%>
            <div>
              <div class="aspect-[3/4] bg-white overflow-hidden">
                <.optimized_image
                  :if={Shared.current_image(@product, @current_image_index)}
                  src={Shared.current_image(@product, @current_image_index)}
                  alt={@product.title}
                  class="w-full h-full object-cover"
                />
                <div
                  :if={!Shared.current_image(@product, @current_image_index)}
                  class="w-full h-full flex items-center justify-center bg-gradient-to-br from-[#FAF6EE] to-[#E7E5E4]"
                >
                  <span class="material-symbols-outlined text-[#5B21B6]/30" style="font-size: 140px;">
                    checkroom
                  </span>
                </div>
              </div>

              <div :if={length(@product.images) > 1} class="grid grid-cols-4 gap-2 mt-3">
                <button
                  :for={{image, idx} <- Enum.with_index(@product.images)}
                  type="button"
                  phx-click="select_image"
                  phx-value-index={idx}
                  class={"aspect-[3/4] overflow-hidden bg-white border-2 transition-colors " <>
                    if(idx == @current_image_index,
                      do: "border-[#5B21B6]",
                      else: "border-transparent hover:border-[#E7E5E4]"
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
            <div class="lg:sticky lg:top-24 lg:self-start">
              <h1 class="fashion-display text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-[1.05] mb-4">
                {@product.title}
              </h1>

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
                      phx-value-value={option_value.id}
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

              <%!-- Trust strip --%>
              <div class="grid grid-cols-3 gap-3 pt-7 border-t border-[#E7E5E4]">
                <div class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#5B21B6] mb-1" style="font-size: 22px;">
                    handyman
                  </span>
                  <p class="text-[10px] uppercase tracking-[0.18em] font-semibold text-[#1C1917]">
                    Hand-sewn
                  </p>
                </div>
                <div class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#5B21B6] mb-1" style="font-size: 22px;">
                    local_shipping
                  </span>
                  <p class="text-[10px] uppercase tracking-[0.18em] font-semibold text-[#1C1917]">
                    Free over GHS 500
                  </p>
                </div>
                <div class="flex flex-col items-start">
                  <span class="material-symbols-outlined text-[#5B21B6] mb-1" style="font-size: 22px;">
                    swap_horiz
                  </span>
                  <p class="text-[10px] uppercase tracking-[0.18em] font-semibold text-[#1C1917]">
                    14-day returns
                  </p>
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

      <Shared.fashion_footer store={@store} />
    </div>
    """
  end

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0
end
