defmodule Emakola.Themes.Electronics.ProductDetail do
  @moduledoc """
  Electronics theme product detail — gallery + monospace price +
  deep-teal "Add to Cart" CTA + warranty pill + stock-aware badge.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Electronics.Shared

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
    <div class="electronics-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.electronics_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumbs --%>
      <div class="bg-[#F5EFE5] border-b border-[#E5E7EB]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <nav class="flex items-center gap-2 text-xs text-[#6B7280]">
            <a href={store_path(@store.slug, "/")} class="hover:text-[#134E4A]">Home</a>
            <span>/</span>
            <a href={store_path(@store.slug, "/products")} class="hover:text-[#134E4A]">Shop</a>
            <span>/</span>
            <span class="text-[#134E4A] font-medium truncate max-w-[200px]">{@product.title}</span>
          </nav>
        </div>
      </div>

      <%!-- Main product --%>
      <section class="bg-[#F5EFE5] py-10 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16">
            <%!-- Gallery --%>
            <div>
              <div class="aspect-square electronics-card overflow-hidden flex items-center justify-center">
                <.optimized_image
                  :if={Shared.current_image(@product, @current_image_index)}
                  src={Shared.current_image(@product, @current_image_index)}
                  alt={@product.title}
                  class="w-full h-full object-contain p-8"
                />
                <span
                  :if={!Shared.current_image(@product, @current_image_index)}
                  class="material-symbols-outlined text-[#134E4A]/20"
                  style="font-size: 140px;"
                >
                  devices
                </span>
              </div>

              <div :if={length(@product.images) > 1} class="flex gap-3 mt-4 overflow-x-auto">
                <button
                  :for={{image, idx} <- Enum.with_index(@product.images)}
                  type="button"
                  phx-click="select_image"
                  phx-value-index={idx}
                  class={"flex-shrink-0 w-20 h-20 rounded-xl overflow-hidden bg-white border-2 transition-colors " <>
                    if(idx == @current_image_index,
                      do: "border-[#0EA5E9]",
                      else: "border-transparent hover:border-[#E5E7EB]"
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

            <%!-- Info --%>
            <div>
              <.stock_badge :if={@selected_variant} variant={@selected_variant} />

              <h1 class="electronics-heading text-3xl sm:text-4xl lg:text-5xl font-extrabold text-[#134E4A] leading-tight mb-4">
                {@product.title}
              </h1>

              <%!-- Rating (real review data only) --%>
              <div
                :if={Map.get(@product, :review_count, 0) > 0}
                class="flex items-center gap-3 mb-6"
              >
                <span class="text-[#134E4A]" style="font-size: 16px;">{stars(@product)}</span>
                <span class="text-xs text-[#6B7280]">
                  ({format_rating(@product)} · {@product.review_count} reviews)
                </span>
              </div>

              <%!-- Price (monospace) --%>
              <div class="flex items-baseline gap-3 mb-6">
                <span class="electronics-mono text-3xl sm:text-4xl font-bold text-[#134E4A]">
                  {EmakolaWeb.Helpers.Currency.format_price(
                    price_for(@product, @selected_variant),
                    Map.get(@store, :currency, "GHS")
                  )}
                </span>
                <%!-- A "1-year warranty" badge used to sit beside the price on
                     every Electronics product. No merchant offered it, none could
                     remove it, and there is no warranty field to derive one from.
                     Warranty terms belong on the store's policies page. --%>
              </div>

              <%!-- Description --%>
              <p :if={@product.description} class="text-base text-[#4B5563] leading-relaxed mb-6">
                {@product.description}
              </p>

              <%!-- Variant options --%>
              <div :if={@option_types != []} class="space-y-5 mb-6">
                <div :for={option_type <- @option_types}>
                  <p class="text-xs font-bold uppercase tracking-wider text-[#134E4A] mb-2">
                    {option_type.name}
                  </p>
                  <div class="flex flex-wrap gap-2">
                    <button
                      :for={option_value <- option_type.option_values || []}
                      type="button"
                      phx-click="select_option"
                      phx-value-option_type_id={option_type.id}
                      phx-value-value={option_value.id}
                      class={"px-4 py-2.5 rounded-xl border-2 text-sm font-medium transition-colors min-h-[44px] " <>
                        if(Map.get(@selected_options, option_type.id) == option_value.id,
                          do: "bg-[#134E4A] text-white border-[#134E4A]",
                          else:
                            "bg-white text-[#1F2937] border-[#E5E7EB] hover:border-[#0EA5E9]"
                        )}
                    >
                      {option_value.value}
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Quantity + add to cart --%>
              <div class="flex flex-col sm:flex-row items-stretch gap-3 mb-7">
                <div class="flex items-center gap-2 px-3 py-2 bg-white rounded-xl border border-[#E5E7EB]">
                  <button
                    type="button"
                    phx-click="decrement_quantity"
                    class="w-9 h-9 rounded-lg hover:bg-[#F3F4F6] flex items-center justify-center"
                    aria-label="Decrease"
                  >
                    <span class="material-symbols-outlined text-[#134E4A]" style="font-size: 18px;">
                      remove
                    </span>
                  </button>
                  <span class="electronics-mono w-10 text-center text-base font-bold text-[#134E4A]">
                    {@quantity}
                  </span>
                  <button
                    type="button"
                    phx-click="increment_quantity"
                    class="w-9 h-9 rounded-lg hover:bg-[#F3F4F6] flex items-center justify-center"
                    aria-label="Increase"
                  >
                    <span class="material-symbols-outlined text-[#134E4A]" style="font-size: 18px;">
                      add
                    </span>
                  </button>
                </div>
                <button
                  type="button"
                  phx-click="add_to_cart"
                  class="flex-1 inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-[var(--theme-primary,#134E4A)] text-white text-sm font-bold hover:bg-[#0E3F3B] transition-colors min-h-[48px]"
                >
                  <span class="material-symbols-outlined" style="font-size: 18px;">shopping_bag</span>
                  Add to Cart
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Related --%>
      <section :if={@related_products != []} class="bg-[#F5EFE5] pb-14 sm:pb-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="electronics-heading text-3xl sm:text-4xl font-extrabold text-[#134E4A] mb-8">
            Related products
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

      <Shared.electronics_footer store={@store} />
    </div>
    """
  end

  # ── Components ──

  attr :variant, :map, required: true

  defp stock_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% @variant.track_inventory and @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#DC2626]/10 text-[#DC2626] text-[11px] font-bold uppercase tracking-wider mb-4">
          <span class="w-1.5 h-1.5 rounded-full bg-[#DC2626]"></span> Out of Stock
        </span>
      <% @variant.track_inventory and @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#D97706]/10 text-[#B45309] text-[11px] font-bold uppercase tracking-wider mb-4">
          <span class="w-1.5 h-1.5 rounded-full bg-[#D97706]"></span>
          Low Stock ({@variant.stock_quantity} left)
        </span>
      <% true -> %>
        <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#10B981]/15 text-[#047857] text-[11px] font-bold uppercase tracking-wider mb-4">
          <span class="w-1.5 h-1.5 rounded-full bg-[#10B981]"></span> In Stock
        </span>
    <% end %>
    """
  end

  # ── Helpers ──

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0

  defp format_rating(product) do
    case Map.get(product, :avg_rating) do
      %Decimal{} = r -> r |> Decimal.round(1) |> Decimal.to_string()
      r when is_float(r) -> :erlang.float_to_binary(r, decimals: 1)
      r when is_integer(r) -> "#{r}.0"
      _ -> "—"
    end
  end

  defp stars(product) do
    n =
      case Map.get(product, :avg_rating) do
        %Decimal{} = r -> r |> Decimal.to_float() |> round()
        r when is_number(r) -> round(r)
        _ -> 0
      end

    n = min(max(n, 0), 5)
    String.duplicate("★", n) <> String.duplicate("☆", 5 - n)
  end
end
