defmodule Emakola.Themes.Beauty.ProductDetail do
  @moduledoc """
  Beauty theme product detail — gallery + dramatic serif title +
  ingredient highlight + warm gold "Add to Bag" CTA.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Beauty.Shared

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
    <div class="beauty-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.beauty_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumbs --%>
      <div class="bg-[#F5EFE5] border-b border-[#E8DBC8]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <nav class="flex items-center gap-2 text-xs text-[#6B4423]/60">
            <a href={store_path(@store.slug, "/")} class="hover:text-[#6B4423]">Home</a>
            <span>/</span>
            <a href={store_path(@store.slug, "/products")} class="hover:text-[#6B4423]">Shop</a>
            <span>/</span>
            <span class="text-[#6B4423] font-medium truncate max-w-[200px]">{@product.title}</span>
          </nav>
        </div>
      </div>

      <%!-- Main product section --%>
      <section class="bg-[#F5EFE5] py-12 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16">
            <%!-- Gallery --%>
            <div>
              <div class="aspect-[4/5] beauty-card overflow-hidden">
                <.optimized_image
                  :if={Shared.current_image(@product, @current_image_index)}
                  src={Shared.current_image(@product, @current_image_index)}
                  alt={@product.title}
                  class="w-full h-full object-cover"
                />
                <div
                  :if={!Shared.current_image(@product, @current_image_index)}
                  class="w-full h-full flex items-center justify-center bg-gradient-to-br from-[#E8DBC8] to-[#C9925E]/20"
                >
                  <span class="material-symbols-outlined text-[#C9925E]" style="font-size: 120px;">
                    spa
                  </span>
                </div>
              </div>

              <%!-- Thumbnails --%>
              <div :if={length(@product.images) > 1} class="flex gap-3 mt-4 overflow-x-auto">
                <button
                  :for={{image, idx} <- Enum.with_index(@product.images)}
                  type="button"
                  phx-click="select_image"
                  phx-value-index={idx}
                  class={"flex-shrink-0 w-20 h-24 rounded-xl overflow-hidden bg-white border-2 transition-colors " <>
                    if(idx == @current_image_index,
                      do: "border-[#C9925E]",
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
              <h1 class="beauty-heading text-4xl sm:text-5xl font-semibold text-[#3D2F25] leading-tight mb-4">
                {@product.title}
              </h1>

              <%!-- Rating (real review data only) --%>
              <div
                :if={Map.get(@product, :review_count, 0) > 0}
                class="flex items-center gap-3 mb-6"
              >
                <span class="text-[#8C5A24]" style="font-size: 16px;">{Shared.stars(@product)}</span>
                <span class="text-xs text-[#6B4423]/60">
                  ({Shared.format_rating(@product)} · {@product.review_count} reviews)
                </span>
              </div>

              <%!-- Price --%>
              <div class="flex items-baseline gap-3 mb-6">
                <span class="beauty-heading text-3xl sm:text-4xl font-semibold text-[var(--theme-primary,#6B4423)]">
                  {EmakolaWeb.Helpers.Currency.format_price(
                    price_for(@product, @selected_variant),
                    Map.get(@store, :currency, "GHS")
                  )}
                </span>
              </div>

              <%!-- Description --%>
              <p :if={@product.description} class="text-base text-[#3D2F25]/80 leading-relaxed mb-6">
                {@product.description}
              </p>

              <%!-- Variant options --%>
              <div :if={@option_types != []} class="space-y-5 mb-6">
                <div :for={option_type <- @option_types}>
                  <p class="text-xs font-semibold uppercase tracking-wider text-[#6B4423] mb-2">
                    {option_type.name}
                  </p>
                  <div class="flex flex-wrap gap-2">
                    <button
                      :for={option_value <- option_type.option_values || []}
                      type="button"
                      phx-click="select_option"
                      phx-value-option_type_id={option_type.id}
                      phx-value-value={option_value.id}
                      class={"px-4 py-2.5 rounded-full border-2 text-sm font-medium transition-colors min-h-[44px] " <>
                        if(Map.get(@selected_options, option_type.id) == option_value.id,
                          do: "bg-[#6B4423] text-[#FAF6EE] border-[#6B4423]",
                          else:
                            "bg-white text-[#3D2F25] border-[#E8DBC8] hover:border-[#C9925E]"
                        )}
                    >
                      {option_value.value}
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Quantity + add to bag --%>
              <div class="flex flex-col sm:flex-row items-stretch gap-3 mb-8">
                <div class="flex items-center gap-2 px-3 py-2 bg-white rounded-full border border-[#E8DBC8]">
                  <button
                    type="button"
                    phx-click="decrement_quantity"
                    class="w-9 h-9 rounded-full hover:bg-[#F5EFE5] flex items-center justify-center"
                    aria-label="Decrease"
                  >
                    <span class="material-symbols-outlined text-[#6B4423]" style="font-size: 18px;">
                      remove
                    </span>
                  </button>
                  <span class="w-10 text-center text-base font-bold text-[#6B4423]">
                    {@quantity}
                  </span>
                  <button
                    type="button"
                    phx-click="increment_quantity"
                    class="w-9 h-9 rounded-full hover:bg-[#F5EFE5] flex items-center justify-center"
                    aria-label="Increase"
                  >
                    <span class="material-symbols-outlined text-[#6B4423]" style="font-size: 18px;">
                      add
                    </span>
                  </button>
                </div>
                <button
                  type="button"
                  phx-click="add_to_cart"
                  class="flex-1 inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-[var(--theme-primary,#6B4423)] text-[#FAF6EE] text-sm font-semibold hover:bg-[#5A381D] transition-colors min-h-[48px]"
                >
                  <span class="material-symbols-outlined" style="font-size: 18px;">shopping_bag</span>
                  Add to Bag
                </button>
              </div>

              <%!-- Trust strip --%>
              <div class="grid grid-cols-3 gap-3 pt-6 border-t border-[#E8DBC8]">
                <div class="flex flex-col items-center text-center">
                  <span class="material-symbols-outlined text-[#6B4423] mb-1" style="font-size: 22px;">
                    spa
                  </span>
                  <p class="text-[10px] uppercase tracking-wider font-semibold text-[#6B4423]">
                    Tested
                  </p>
                </div>
                <div class="flex flex-col items-center text-center">
                  <span class="material-symbols-outlined text-[#6B4423] mb-1" style="font-size: 22px;">
                    compost
                  </span>
                  <p class="text-[10px] uppercase tracking-wider font-semibold text-[#6B4423]">
                    Eco-packed
                  </p>
                </div>
                <div class="flex flex-col items-center text-center">
                  <span class="material-symbols-outlined text-[#6B4423] mb-1" style="font-size: 22px;">
                    local_florist
                  </span>
                  <p class="text-[10px] uppercase tracking-wider font-semibold text-[#6B4423]">
                    Botanical
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Related --%>
      <section :if={@related_products != []} class="bg-[#F5EFE5] pb-16 sm:pb-24">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="beauty-heading text-3xl sm:text-4xl font-semibold text-[#3D2F25] mb-8 text-center">
            You may also love
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

      <Shared.beauty_footer store={@store} />
    </div>
    """
  end

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0
end
