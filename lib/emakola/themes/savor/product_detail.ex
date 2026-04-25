defmodule Emakola.Themes.Savor.ProductDetail do
  @moduledoc """
  Savor theme product detail page (PDP) — built for restaurant dishes.

  Layout:
    * Sticky Savor nav + breadcrumb
    * Two-column on desktop: image gallery (left, 55%) + dish info (right, 45%)
    * Title in Anton uppercase, price in tabular nums
    * Variant selector (size / portion / spice level — pill-shaped)
    * Quantity stepper
    * Dual CTA stack: ADD TO BAG (dark) + Order on WhatsApp (green)
    * Ingredients & allergens block (always visible — restaurants need this)
    * Cook time / portion info strip
    * Related dishes ("Pairs well with") cross-sell
    * Restaurant footer
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Savor.Shared
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
    <div class="min-h-screen bg-[#FFFBEB]">
      <Shared.theme_styles theme={@theme} />
      <Shared.savor_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumb --%>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-4">
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-xs text-[#78350F] hover:text-[var(--theme-primary,#DC2626)] transition-colors inline-flex items-center gap-1.5 tracking-wide"
          style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"
            />
          </svg>
          BACK TO MENU
        </a>
      </div>

      <main class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-10">
        <div class="grid grid-cols-1 lg:grid-cols-[55%_45%] gap-8 lg:gap-12">
          <%!-- Image gallery ── --%>
          <div>
            <div class="aspect-square bg-[#FEF3C7]/40 rounded-3xl overflow-hidden mb-3">
              <%= if @current_image do %>
                <.optimized_image
                  src={@current_image}
                  alt={@product.title}
                  priority={:high}
                  class="w-full h-full object-cover"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <span class="material-symbols-outlined text-7xl text-[#D97706]">restaurant</span>
                </div>
              <% end %>
            </div>

            <div :if={length(@images) > 1} class="grid grid-cols-4 gap-2 sm:gap-3">
              <a
                :for={{src, idx} <- Enum.with_index(Enum.take(@images, 4))}
                href={"?image=#{idx}"}
                class={[
                  "block aspect-square rounded-xl overflow-hidden border-2 transition-all",
                  if(idx == @current_image_index,
                    do: "border-[var(--theme-primary,#DC2626)]",
                    else: "border-transparent hover:border-[#FDE68A]"
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

          <%!-- Dish info ── --%>
          <div>
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#DC2626)] mb-2">
              On the menu today
            </p>
            <h1
              class="text-3xl sm:text-4xl lg:text-5xl text-[#1C1917] mb-3 leading-tight tracking-wide"
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              {String.upcase(@product.title)}
            </h1>
            <p
              class="text-3xl text-[var(--theme-primary,#DC2626)] mb-5 tabular-nums"
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              {format_price(@price, @store.currency)}
            </p>

            <p
              :if={@product.description}
              class="text-base text-[#44403C] leading-relaxed mb-6"
              style="font-family: 'Lora', serif;"
            >
              {@product.description}
            </p>

            <%!-- Option pickers ── --%>
            <div :if={@option_types != []} class="space-y-5 mb-6">
              <div :for={option_type <- @option_types}>
                <p
                  class="text-xs font-bold tracking-[0.2em] uppercase text-[#78350F] mb-2"
                  style="font-family: 'Lora', serif;"
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
                      "inline-flex items-center px-4 py-2 rounded-full text-xs font-bold tracking-wide transition-all",
                      if(option_value_selected?(@selected_options, option_type.id, value.id),
                        do: "bg-[#1C1917] text-white border-2 border-[#1C1917]",
                        else:
                          "bg-white text-[#78350F] border-2 border-[#FDE68A] hover:border-[var(--theme-primary,#DC2626)]"
                      )
                    ]}
                    style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
                  >
                    {String.upcase(value.value)}
                  </button>
                </div>
              </div>
            </div>

            <%!-- Quantity ── --%>
            <div class="flex items-center gap-4 mb-6">
              <p
                class="text-xs font-bold tracking-[0.2em] uppercase text-[#78350F]"
                style="font-family: 'Lora', serif;"
              >
                Quantity
              </p>
              <div class="inline-flex items-center bg-white border-2 border-[#FDE68A] rounded-full overflow-hidden">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  class="w-10 h-10 flex items-center justify-center text-[#78350F] hover:bg-[#FEF3C7] transition-colors disabled:opacity-30"
                  disabled={@quantity <= 1}
                  aria-label="Decrease quantity"
                >
                  <span class="material-symbols-outlined text-[20px]">remove</span>
                </button>
                <span
                  class="w-10 text-center text-base font-bold text-[#1C1917] tabular-nums"
                  style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
                >
                  {@quantity}
                </span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  class="w-10 h-10 flex items-center justify-center text-[#78350F] hover:bg-[#FEF3C7] transition-colors"
                  aria-label="Increase quantity"
                >
                  <span class="material-symbols-outlined text-[20px]">add</span>
                </button>
              </div>
            </div>

            <%!-- Dual CTA stack ── --%>
            <div class="space-y-3 mb-8">
              <button
                type="button"
                phx-click="add_to_cart"
                class="w-full flex items-center justify-center gap-2 py-4 px-6 bg-[#1C1917] text-white rounded-full text-base font-bold hover:bg-[#292524] active:scale-[0.97] transition-all shadow-lg shadow-stone-900/20 leading-none tracking-wide"
                style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
              >
                <svg
                  class="w-5 h-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007z"
                  />
                </svg>
                ADD TO BAG · {format_price(line_total(@price, @quantity), @store.currency)}
              </button>
              <a
                :if={Map.get(@store, :whatsapp_number)}
                href={whatsapp_order_link(@store, @product, @quantity)}
                target="_blank"
                rel="noopener noreferrer"
                class="w-full flex items-center justify-center gap-2 py-4 px-6 bg-[#25D366] text-white rounded-full text-base font-semibold hover:bg-[#1FB855] active:scale-[0.97] transition-all shadow-lg shadow-green-900/20 leading-none"
                style="font-family: 'Lora', serif;"
              >
                <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347" />
                </svg>
                Order on WhatsApp
              </a>
            </div>

            <%!-- Service info strip ── --%>
            <div class="grid grid-cols-3 gap-3 py-5 border-y border-[#FDE68A]/60">
              <div class="text-center">
                <span class="material-symbols-outlined text-[24px] text-[var(--theme-accent,#15803D)] block mb-1">
                  schedule
                </span>
                <p class="text-[11px] text-[#78350F]" style="font-family: 'Lora', serif;">
                  Cooked to order
                </p>
              </div>
              <div class="text-center">
                <span class="material-symbols-outlined text-[24px] text-[var(--theme-accent,#15803D)] block mb-1">
                  delivery_dining
                </span>
                <p class="text-[11px] text-[#78350F]" style="font-family: 'Lora', serif;">
                  Same-day delivery
                </p>
              </div>
              <div class="text-center">
                <span class="material-symbols-outlined text-[24px] text-[var(--theme-accent,#15803D)] block mb-1">
                  payments
                </span>
                <p class="text-[11px] text-[#78350F]" style="font-family: 'Lora', serif;">
                  Cash on delivery
                </p>
              </div>
            </div>
          </div>
        </div>

        <%!-- Pairs well with ── --%>
        <section :if={@related_products != []} class="mt-16">
          <div class="mb-6 sm:mb-8">
            <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#DC2626)] mb-2">
              Round it out
            </p>
            <h2
              class="text-2xl sm:text-3xl text-[#1C1917] tracking-wide"
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              PAIRS WELL WITH
            </h2>
          </div>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
            <Shared.dish_card
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

  defp whatsapp_order_link(store, product, quantity) do
    number = normalise_whatsapp(store.whatsapp_number)

    text =
      "Hello #{store.name}, I'd like to order #{quantity} × #{product.title}."
      |> URI.encode_www_form()

    "https://wa.me/#{number}?text=#{text}"
  end

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end
end
