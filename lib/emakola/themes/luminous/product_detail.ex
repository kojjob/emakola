defmodule Emakola.Themes.Luminous.ProductDetail do
  @moduledoc """
  Luminous theme product detail page (PDP) — built for beauty / cosmetics.

  Layout:
    * Sticky Luminous nav + breadcrumb
    * Two-column desktop (50/50): image gallery + product info
    * Italic serif title in Cormorant Garamond, rose price
    * Variant pickers — circular swatches for shade, pill chips for size
    * Quantity stepper + dual CTA: Add to bag (dark) + Add to routine (rose)
    * Hero ingredient highlight panel
    * "How to use" + "What's inside" accordion-style blocks
    * "Pairs well with" cross-sell strip
    * Beauty-brand footer
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Luminous.Shared
  alias EmakolaWeb.Helpers.Currency

  attr :store, :map, required: true
  attr :product, :map, required: true
  attr :selected_variant, :map, default: nil
  attr :selected_options, :map, default: %{}
  attr :option_types, :list, default: []
  attr :quantity, :integer, default: 1
  attr :current_image_index, :integer, default: 0
  attr :related_products, :list, default: []
  attr :categories, :list, default: []
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:images, fn -> product_images(assigns.product) end)
      |> assign_new(:current_image, fn ->
        Enum.at(product_images(assigns.product), assigns.current_image_index || 0)
      end)
      |> assign_new(:price, fn ->
        active_price(assigns.product, assigns.selected_variant)
      end)

    ~H"""
    <div class="min-h-screen bg-[#FFFBF8]">
      <Shared.theme_styles theme={@theme} />
      <Shared.luminous_nav store={@store} cart_count={@cart_count} />

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-4">
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-xs text-[#78716C] hover:text-[var(--theme-primary,#DB2777)] transition-colors inline-flex items-center gap-1.5 tracking-wide"
          style="font-family: 'Inter', sans-serif;"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"
            />
          </svg>
          Back to shop
        </a>
      </div>

      <main class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-10">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-14">
          <%!-- Image gallery ── --%>
          <div>
            <div class="aspect-square bg-[#FCE7F3]/30 rounded-3xl overflow-hidden mb-3">
              <%= if @current_image do %>
                <.optimized_image
                  src={@current_image}
                  alt={@product.title}
                  priority={:high}
                  class="w-full h-full object-cover"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <span class="material-symbols-outlined text-7xl text-[var(--theme-primary,#DB2777)]/40">
                    spa
                  </span>
                </div>
              <% end %>
            </div>

            <div :if={length(@images) > 1} class="grid grid-cols-4 gap-2 sm:gap-3">
              <a
                :for={{src, idx} <- Enum.with_index(Enum.take(@images, 4))}
                href={"?image=#{idx}"}
                class={[
                  "block aspect-square rounded-2xl overflow-hidden border-2 transition-all",
                  if(idx == @current_image_index,
                    do: "border-[var(--theme-primary,#DB2777)]",
                    else: "border-transparent hover:border-[#FBCFE8]"
                  )
                ]}
              >
                <.optimized_image
                  src={src}
                  alt={"#{@product.title} view #{idx + 1}"}
                  priority={:low}
                  class="w-full h-full object-cover"
                />
              </a>
            </div>
          </div>

          <%!-- Product info ── --%>
          <div>
            <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-primary,#DB2777)] mb-3">
              Ingredient-honest
            </p>
            <h1
              class="text-4xl sm:text-5xl text-[#1F1717] mb-3 leading-tight italic"
              style="font-family: 'Cormorant Garamond', serif;"
            >
              {@product.title}
            </h1>
            <p class="text-2xl font-semibold text-[var(--theme-primary,#DB2777)] mb-5 tabular-nums">
              {format_price(@price, @store.currency)}
            </p>

            <p
              :if={@product.description}
              class="text-base text-[#57534E] leading-relaxed mb-6"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.description}
            </p>

            <%!-- Hero ingredient highlight ── --%>
            <div class="rounded-2xl bg-[#FCE7F3]/60 border border-[#FBCFE8]/60 p-5 mb-6 flex items-start gap-3">
              <span class="flex-shrink-0 w-10 h-10 rounded-full bg-white flex items-center justify-center">
                <span class="material-symbols-outlined text-[20px] text-[var(--theme-primary,#DB2777)]">
                  auto_awesome
                </span>
              </span>
              <div class="min-w-0">
                <p
                  class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[#9D174D] mb-1"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Hero ingredient
                </p>
                <p
                  class="text-sm text-[#1F1717]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Wild-harvested shea — anti-inflammatory, deeply nourishing, sourced from a women's
                  cooperative in northern Ghana.
                </p>
              </div>
            </div>

            <%!-- Option pickers ── --%>
            <div :if={@option_types != []} class="space-y-5 mb-6">
              <div :for={option_type <- @option_types}>
                <p
                  class="text-xs font-semibold tracking-[0.15em] uppercase text-[#78716C] mb-2"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {option_type.name}
                </p>
                <div class="flex flex-wrap gap-2">
                  <button
                    :for={value <- option_type.option_values}
                    type="button"
                    phx-click="select_option"
                    phx-value-option-type-id={option_type.id}
                    phx-value-option-value-id={value.id}
                    class={[
                      "inline-flex items-center px-4 py-2 rounded-full text-xs font-medium transition-all",
                      if(option_value_selected?(@selected_options, option_type.id, value.id),
                        do: "bg-[#1F1717] text-white border-2 border-[#1F1717]",
                        else:
                          "bg-white text-[#78716C] border-2 border-[#FBCFE8] hover:border-[var(--theme-primary,#DB2777)]"
                      )
                    ]}
                    style="font-family: 'Inter', sans-serif;"
                  >
                    {value.value}
                  </button>
                </div>
              </div>
            </div>

            <%!-- Quantity ── --%>
            <div class="flex items-center gap-4 mb-6">
              <p
                class="text-xs font-semibold tracking-[0.15em] uppercase text-[#78716C]"
                style="font-family: 'Inter', sans-serif;"
              >
                Quantity
              </p>
              <div class="inline-flex items-center bg-white border-2 border-[#FBCFE8] rounded-full overflow-hidden">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  class="w-10 h-10 flex items-center justify-center text-[#78716C] hover:bg-[#FCE7F3] transition-colors disabled:opacity-30"
                  disabled={@quantity <= 1}
                  aria-label="Decrease quantity"
                >
                  <span class="material-symbols-outlined text-[20px]">remove</span>
                </button>
                <span
                  class="w-10 text-center text-base font-semibold text-[#1F1717] tabular-nums"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {@quantity}
                </span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  class="w-10 h-10 flex items-center justify-center text-[#78716C] hover:bg-[#FCE7F3] transition-colors"
                  aria-label="Increase quantity"
                >
                  <span class="material-symbols-outlined text-[20px]">add</span>
                </button>
              </div>
            </div>

            <%!-- Dual CTA ── --%>
            <div class="space-y-3 mb-8">
              <button
                type="button"
                phx-click="add_to_cart"
                class="w-full flex items-center justify-center gap-2 py-4 px-6 bg-[#1F1717] text-white rounded-full text-sm font-semibold hover:bg-[#292524] active:scale-[0.97] transition-all shadow-lg shadow-stone-900/20 leading-none"
                style="font-family: 'Inter', sans-serif;"
              >
                Add to bag · {format_price(line_total(@price, @quantity), @store.currency)}
              </button>
              <button
                type="button"
                phx-click="add_to_routine"
                class="w-full flex items-center justify-center gap-2 py-4 px-6 bg-[var(--theme-primary,#DB2777)] text-white rounded-full text-sm font-semibold hover:bg-[#9D174D] active:scale-[0.97] transition-all shadow-md shadow-pink-300/40 leading-none"
                style="font-family: 'Inter', sans-serif;"
              >
                <span class="material-symbols-outlined text-[18px]">favorite</span> Save to routine
              </button>
            </div>

            <%!-- How to use + What's inside ── --%>
            <div class="space-y-3">
              <details class="group rounded-2xl border border-[#FBCFE8]/60 bg-white">
                <summary
                  class="cursor-pointer list-none px-5 py-4 flex items-center justify-between text-sm font-semibold text-[#1F1717]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  How to use
                  <span class="material-symbols-outlined text-[20px] text-[var(--theme-primary,#DB2777)] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-5 pb-5 text-sm text-[#57534E] leading-relaxed"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Apply a small amount morning and night onto clean skin. For best results, layer
                  under SPF in the morning and pair with your favourite serum at night.
                </div>
              </details>
              <details class="group rounded-2xl border border-[#FBCFE8]/60 bg-white">
                <summary
                  class="cursor-pointer list-none px-5 py-4 flex items-center justify-between text-sm font-semibold text-[#1F1717]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  What's inside
                  <span class="material-symbols-outlined text-[20px] text-[var(--theme-primary,#DB2777)] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-5 pb-5 text-sm text-[#57534E] leading-relaxed"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Wild-harvested shea, baobab oil, vitamin E, hibiscus extract. No parabens, no
                  sulphates, no synthetic fragrance. Cruelty-free and dermatologist-tested.
                </div>
              </details>
              <details class="group rounded-2xl border border-[#FBCFE8]/60 bg-white">
                <summary
                  class="cursor-pointer list-none px-5 py-4 flex items-center justify-between text-sm font-semibold text-[#1F1717]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Shipping & returns
                  <span class="material-symbols-outlined text-[20px] text-[var(--theme-primary,#DB2777)] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-5 pb-5 text-sm text-[#57534E] leading-relaxed"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Free shipping on orders over GH₵250. 14-day returns on unopened items. Discreet
                  packaging always.
                </div>
              </details>
            </div>
          </div>
        </div>

        <%!-- Pairs well with ── --%>
        <section :if={@related_products != []} class="mt-16">
          <div class="mb-6 sm:mb-8 text-center">
            <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-primary,#DB2777)] mb-2">
              Build the routine
            </p>
            <h2
              class="text-3xl sm:text-4xl text-[#1F1717] italic"
              style="font-family: 'Cormorant Garamond', serif;"
            >
              Pairs well with
            </h2>
          </div>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
            <Shared.beauty_card
              :for={related <- Enum.take(@related_products, 4)}
              product={related}
              store={@store}
            />
          </div>
        </section>
      </main>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Helpers ──

  defp product_images(product) do
    case product.images do
      images when is_list(images) ->
        images
        |> Enum.map(fn
          %{url: url} when is_binary(url) -> url
          %{thumbnail_url: url} when is_binary(url) -> url
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp active_price(_product, %{price: price}) when is_integer(price), do: price

  defp active_price(product, _) do
    Map.get(product, :min_price) || Map.get(product, :max_price)
  end

  defp format_price(nil, _currency), do: "Price not set"

  defp format_price(amount, currency) when is_integer(amount) do
    Currency.format_price(amount, currency)
  end

  defp line_total(nil, _qty), do: nil

  defp line_total(price, qty) when is_integer(price) and is_integer(qty) and qty > 0,
    do: price * qty

  defp line_total(price, _qty), do: price

  defp option_value_selected?(selected_options, option_type_id, option_value_id) do
    Map.get(selected_options, option_type_id) == option_value_id
  end
end
