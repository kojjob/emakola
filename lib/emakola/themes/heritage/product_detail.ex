defmodule Emakola.Themes.Heritage.ProductDetail do
  @moduledoc """
  Heritage theme product detail — gallery + Playfair italic title +
  artisan provenance card + burgundy "Add to Cart" CTA.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Heritage.Shared

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
    <div class="heritage-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.heritage_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumbs --%>
      <div class="bg-[#FAF6EC] border-b border-[#E8DBC2]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <nav class="flex items-center gap-2 text-xs text-[#6B4423]/60">
            <a href={store_path(@store.slug, "/")} class="hover:text-[#7A1F1F]">Marketplace</a>
            <span>/</span>
            <a href={store_path(@store.slug, "/products")} class="hover:text-[#7A1F1F]">Collection</a>
            <span>/</span>
            <span class="text-[#7A1F1F] font-semibold truncate max-w-[200px]">
              {@product.title}
            </span>
          </nav>
        </div>
      </div>

      <%!-- Main product section --%>
      <section class="bg-[#FAF6EC] py-12 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16">
            <%!-- Gallery --%>
            <div>
              <div class="aspect-[4/5] heritage-card overflow-hidden bg-[#F5EFE0]">
                <.optimized_image
                  :if={Shared.current_image(@product, @current_image_index)}
                  src={Shared.current_image(@product, @current_image_index)}
                  alt={@product.title}
                  class="w-full h-full object-cover"
                />
                <div
                  :if={!Shared.current_image(@product, @current_image_index)}
                  class="w-full h-full flex items-center justify-center bg-gradient-to-br from-[#E8DBC2] to-[#D4A843]/30"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-32 h-32 text-[#7A1F1F]/30"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
                  </svg>
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
                      do: "border-[#D4A843]",
                      else: "border-transparent hover:border-[#E8DBC2]"
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
              <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#D4A843]/20 text-[#7A1F1F] text-[10px] font-bold uppercase tracking-[0.2em] mb-5">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-3.5 h-3.5"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M8.6 2.5a3 3 0 0 1 4.8 0 3 3 0 0 1 3.4 1.4 3 3 0 0 1 2.7 2.7 3 3 0 0 1 1.4 3.4 3 3 0 0 1 0 4.8 3 3 0 0 1-1.4 3.4 3 3 0 0 1-2.7 2.7 3 3 0 0 1-3.4 1.4 3 3 0 0 1-4.8 0 3 3 0 0 1-3.4-1.4 3 3 0 0 1-2.7-2.7 3 3 0 0 1-1.4-3.4 3 3 0 0 1 0-4.8 3 3 0 0 1 1.4-3.4 3 3 0 0 1 2.7-2.7A3 3 0 0 1 8.6 2.5Zm7.7 6.7a1 1 0 0 0-1.4-1.4l-4.4 4.4-1.7-1.7a1 1 0 1 0-1.4 1.4l2.4 2.4a1 1 0 0 0 1.4 0l5.1-5.1Z"
                    clip-rule="evenodd"
                  />
                </svg>
                Heritage Certified
              </span>

              <h1 class="heritage-heading text-4xl sm:text-5xl font-bold text-[#3D2817] leading-tight mb-4">
                {@product.title}
              </h1>

              <%!-- Price --%>
              <div class="flex items-baseline gap-3 mb-6">
                <span class="heritage-heading text-3xl sm:text-4xl font-bold text-[#7A1F1F]">
                  {EmakolaWeb.Helpers.Currency.format_price(
                    price_for(@product, @selected_variant),
                    Map.get(@store, :currency, "GHS")
                  )}
                </span>
              </div>

              <%!-- Description --%>
              <p
                :if={@product.description}
                class="heritage-italic text-base text-[#3D2817]/85 leading-relaxed mb-6 border-l-2 border-[#D4A843] pl-4"
              >
                {@product.description}
              </p>

              <%!-- Variant options --%>
              <div :if={@option_types != []} class="space-y-5 mb-6">
                <div :for={option_type <- @option_types}>
                  <p class="text-xs font-bold uppercase tracking-[0.2em] text-[#7A1F1F] mb-2">
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
                          do: "bg-[#7A1F1F] text-[#F5EFE0] border-[#7A1F1F]",
                          else:
                            "bg-white text-[#3D2817] border-[#E8DBC2] hover:border-[#D4A843]"
                        )}
                    >
                      {option_value.value}
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Quantity + add to cart --%>
              <div class="flex flex-col sm:flex-row items-stretch gap-3 mb-8">
                <div class="flex items-center gap-2 px-3 py-2 bg-white rounded-full border border-[#E8DBC2]">
                  <button
                    type="button"
                    phx-click="decrement_quantity"
                    class="w-9 h-9 rounded-full hover:bg-[#FAF6EC] flex items-center justify-center"
                    aria-label="Decrease"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 24 24"
                      class="w-4 h-4 text-[#7A1F1F]"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2.5"
                      stroke-linecap="round"
                    >
                      <path d="M5 12h14" />
                    </svg>
                  </button>
                  <span class="w-10 text-center text-base font-bold text-[#7A1F1F]">
                    {@quantity}
                  </span>
                  <button
                    type="button"
                    phx-click="increment_quantity"
                    class="w-9 h-9 rounded-full hover:bg-[#FAF6EC] flex items-center justify-center"
                    aria-label="Increase"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 24 24"
                      class="w-4 h-4 text-[#7A1F1F]"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2.5"
                      stroke-linecap="round"
                    >
                      <path d="M12 5v14M5 12h14" />
                    </svg>
                  </button>
                </div>
                <button
                  type="button"
                  phx-click="add_to_cart"
                  class="flex-1 inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-[#7A1F1F] text-[#F5EFE0] text-sm font-bold uppercase tracking-wider hover:bg-[#5A1717] transition-colors min-h-[48px]"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z" />
                    <path d="M3 6h18M16 10a4 4 0 0 1-8 0" />
                  </svg>
                  Add to Cart
                </button>
              </div>

              <%!-- Provenance card (artisan signature row) --%>
              <div class="rounded-2xl bg-white border border-[#E8DBC2] p-5">
                <p class="text-[10px] font-bold uppercase tracking-[0.25em] text-[#D4A843] mb-2">
                  Provenance
                </p>
                <div class="grid grid-cols-3 gap-3 text-center">
                  <div>
                    <p class="heritage-heading text-2xl font-bold text-[#7A1F1F]">100%</p>
                    <p class="text-[10px] uppercase tracking-wider font-semibold text-[#6B4423]">
                      Hand-made
                    </p>
                  </div>
                  <div class="border-x border-[#E8DBC2]">
                    <p class="heritage-heading text-2xl font-bold text-[#7A1F1F]">Fair</p>
                    <p class="text-[10px] uppercase tracking-wider font-semibold text-[#6B4423]">
                      Trade
                    </p>
                  </div>
                  <div>
                    <p class="heritage-heading text-2xl font-bold text-[#7A1F1F]">∞</p>
                    <p class="text-[10px] uppercase tracking-wider font-semibold text-[#6B4423]">
                      Heritage
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Related --%>
      <section :if={@related_products != []} class="bg-[#FAF6EC] pb-16 sm:pb-24">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="heritage-heading text-3xl sm:text-4xl font-bold text-[#7A1F1F] mb-8 text-center">
            From the same collection
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

      <Shared.heritage_footer store={@store} />
    </div>
    """
  end

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0
end
