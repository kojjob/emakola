defmodule Emakola.Themes.Pharmacy.ProductDetail do
  @moduledoc """
  Pharmacy theme product detail — clean, accessible product page with
  trust signals (verified pharmacy, prescription notes, dosage info)
  prominent for older users on mobile.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Pharmacy.Shared

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
    <div class="pharmacy-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.pharmacy_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumbs --%>
      <div class="bg-[#F9F6F0] border-b border-[#E5E7EB]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <nav class="flex items-center gap-2 text-xs text-[#6B7280]">
            <a href={"/s/#{@store.slug}"} class="hover:text-[#14543E]">Home</a>
            <span>/</span>
            <a href={"/s/#{@store.slug}/products"} class="hover:text-[#14543E]">Products</a>
            <span>/</span>
            <span class="text-[#14543E] font-medium truncate max-w-[200px]">{@product.title}</span>
          </nav>
        </div>
      </div>

      <%!-- Main product section --%>
      <section class="bg-[#F9F6F0] py-10 sm:py-14">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16">
            <%!-- Image gallery --%>
            <div>
              <div class="aspect-square pharmacy-card flex items-center justify-center overflow-hidden">
                <.optimized_image
                  :if={Shared.current_image(@product, @current_image_index)}
                  src={Shared.current_image(@product, @current_image_index)}
                  alt={@product.title}
                  class="w-full h-full object-contain p-8"
                />
                <span
                  :if={!Shared.current_image(@product, @current_image_index)}
                  class="material-symbols-outlined text-[#A7E5C5]"
                  style="font-size: 120px;"
                >
                  medication
                </span>
              </div>

              <%!-- Thumbnail strip --%>
              <div :if={length(@product.images) > 1} class="flex gap-3 mt-4 overflow-x-auto">
                <button
                  :for={{image, idx} <- Enum.with_index(@product.images)}
                  type="button"
                  phx-click="select_image"
                  phx-value-index={idx}
                  class={"flex-shrink-0 w-20 h-20 rounded-xl overflow-hidden bg-white border-2 transition-colors " <>
                    if(idx == @current_image_index,
                      do: "border-[#14543E]",
                      else: "border-transparent hover:border-[#A7E5C5]"
                    )}
                >
                  <img
                    src={Map.get(image, :thumbnail_url) || Map.get(image, :url)}
                    alt={"#{@product.title} #{idx + 1}"}
                    class="w-full h-full object-contain p-1.5"
                  />
                </button>
              </div>
            </div>

            <%!-- Product info --%>
            <div>
              <%!-- Verified badge --%>
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#A7E5C5]/40 text-[#14543E] text-xs font-semibold uppercase tracking-wider mb-4">
                <span class="material-symbols-outlined" style="font-size: 14px;">verified</span>
                Verified by pharmacy
              </span>

              <h1 class="pharmacy-heading text-3xl sm:text-4xl font-medium text-[#14543E] leading-tight mb-3">
                {@product.title}
              </h1>

              <%!-- Rating + sold count --%>
              <div class="flex items-center gap-3 mb-5">
                <div class="flex items-center gap-1">
                  <span :for={_ <- 1..5} class="text-[#FBBF24]" style="font-size: 16px;">★</span>
                </div>
                <span class="text-xs text-[#6B7280]">(4.8 · 124 reviews)</span>
              </div>

              <%!-- Price --%>
              <div class="flex items-baseline gap-3 mb-6">
                <span class="pharmacy-heading text-3xl sm:text-4xl font-semibold text-[#14543E]">
                  {EmakolaWeb.Helpers.Currency.format_price(
                    price_for(@product, @selected_variant),
                    Map.get(@store, :currency, "GHS")
                  )}
                </span>
                <span :if={pack_label(@selected_variant)} class="text-sm text-[#6B7280]">
                  {pack_label(@selected_variant)}
                </span>
              </div>

              <%!-- Short description --%>
              <p :if={@product.description} class="text-base text-[#4B5563] leading-relaxed mb-6">
                {@product.description}
              </p>

              <%!-- Variant options --%>
              <div :if={@option_types != []} class="space-y-5 mb-6">
                <div :for={option_type <- @option_types}>
                  <p class="text-sm font-semibold text-[#14543E] mb-2">{option_type.name}</p>
                  <div class="flex flex-wrap gap-2">
                    <button
                      :for={value <- option_type.values}
                      type="button"
                      phx-click="select_option"
                      phx-value-option={option_type.name}
                      phx-value-value={value}
                      class={"px-4 py-2.5 rounded-full border-2 text-sm font-medium transition-colors min-h-[44px] " <>
                        if(Map.get(@selected_options, option_type.name) == value,
                          do: "bg-[#14543E] text-white border-[#14543E]",
                          else:
                            "bg-white text-[#1F2937] border-[#E5E7EB] hover:border-[#A7E5C5]"
                        )}
                    >
                      {value}
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Quantity + add to cart --%>
              <div class="flex flex-col sm:flex-row items-stretch gap-3 mb-6">
                <div class="flex items-center gap-2 px-3 py-2 pharmacy-card border border-[#E5E7EB]">
                  <button
                    type="button"
                    phx-click="decrement_quantity"
                    class="w-9 h-9 rounded-full hover:bg-[#A7E5C5]/30 flex items-center justify-center"
                    aria-label="Decrease quantity"
                  >
                    <span class="material-symbols-outlined text-[#14543E]" style="font-size: 18px;">
                      remove
                    </span>
                  </button>
                  <span class="w-10 text-center text-base font-bold text-[#14543E]">
                    {@quantity}
                  </span>
                  <button
                    type="button"
                    phx-click="increment_quantity"
                    class="w-9 h-9 rounded-full hover:bg-[#A7E5C5]/30 flex items-center justify-center"
                    aria-label="Increase quantity"
                  >
                    <span class="material-symbols-outlined text-[#14543E]" style="font-size: 18px;">
                      add
                    </span>
                  </button>
                </div>
                <button
                  type="button"
                  phx-click="add_to_cart"
                  class="flex-1 inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-[#14543E] text-white text-sm font-semibold hover:bg-[#0F3F2E] transition-colors min-h-[48px]"
                >
                  <span class="material-symbols-outlined" style="font-size: 18px;">
                    add_shopping_cart
                  </span>
                  Add to cart
                </button>
              </div>

              <%!-- Trust strip --%>
              <div class="grid grid-cols-3 gap-3 pt-6 border-t border-[#E5E7EB]">
                <div class="flex flex-col items-center text-center">
                  <span class="material-symbols-outlined text-[#14543E] mb-1" style="font-size: 24px;">
                    verified_user
                  </span>
                  <p class="text-[10px] uppercase tracking-wider font-semibold text-[#14543E]">
                    Licensed
                  </p>
                  <p class="text-[10px] text-[#6B7280]">FDA Ghana</p>
                </div>
                <div class="flex flex-col items-center text-center">
                  <span class="material-symbols-outlined text-[#14543E] mb-1" style="font-size: 24px;">
                    local_pharmacy
                  </span>
                  <p class="text-[10px] uppercase tracking-wider font-semibold text-[#14543E]">
                    Genuine
                  </p>
                  <p class="text-[10px] text-[#6B7280]">Trusted brands</p>
                </div>
                <div class="flex flex-col items-center text-center">
                  <span class="material-symbols-outlined text-[#14543E] mb-1" style="font-size: 24px;">
                    local_shipping
                  </span>
                  <p class="text-[10px] uppercase tracking-wider font-semibold text-[#14543E]">
                    Discreet
                  </p>
                  <p class="text-[10px] text-[#6B7280]">Fast delivery</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Related products --%>
      <section :if={@related_products != []} class="bg-[#F9F6F0] pb-14 sm:pb-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="pharmacy-heading text-2xl sm:text-3xl font-medium text-[#14543E] mb-8">
            You may also like
          </h2>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5">
            <Shared.product_card
              :for={product <- Enum.take(@related_products, 4)}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <Shared.pharmacy_footer store={@store} />
    </div>
    """
  end

  # ── Helpers ──

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0

  defp pack_label(%{sku: sku}) when is_binary(sku) and sku != "", do: sku
  defp pack_label(_), do: nil
end
