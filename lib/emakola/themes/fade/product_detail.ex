defmodule Emakola.Themes.Fade.ProductDetail do
  @moduledoc """
  Fade theme PDP — drop-driven, dark, hard-edged.
  Two-column desktop, gallery + sticky info. Variant pickers as squares.
  Single primary CTA (neon green). Sold-out state replaces CTA with disabled state.
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Fade.Shared
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
    <div class="min-h-screen bg-[#0A0A0A] text-[#FAFAFA]">
      <Shared.theme_styles theme={@theme} />
      <Shared.fade_nav store={@store} cart_count={@cart_count} />

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-6">
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-[10px] uppercase tracking-[0.25em] text-[#A3A3A3] hover:text-white transition-colors inline-flex items-center gap-1.5"
          style="font-family: 'Space Grotesk', sans-serif;"
        >
          ← All drops
        </a>
      </div>

      <main class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-12">
        <div class="grid grid-cols-1 lg:grid-cols-[60%_40%] gap-8 lg:gap-14">
          <%!-- Image gallery ── --%>
          <div>
            <div class="aspect-square bg-[#1F1F1F] overflow-hidden mb-3">
              <%= if @current_image do %>
                <.optimized_image
                  src={@current_image}
                  alt={@product.title}
                  priority={:high}
                  class="w-full h-full object-cover"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <span class="material-symbols-outlined text-7xl text-[#404040]">checkroom</span>
                </div>
              <% end %>
            </div>

            <div :if={length(@images) > 1} class="grid grid-cols-4 gap-2">
              <a
                :for={{src, idx} <- Enum.with_index(Enum.take(@images, 4))}
                href={"?image=#{idx}"}
                class={[
                  "block aspect-square overflow-hidden border-2 transition-colors",
                  if(idx == @current_image_index,
                    do: "border-[var(--theme-accent,#00FF85)]",
                    else: "border-transparent hover:border-[#404040]"
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
          <div class="lg:sticky lg:top-24 lg:self-start">
            <p class="text-[10px] font-bold tracking-[0.3em] uppercase text-[var(--theme-accent,#00FF85)] mb-3">
              Drop · {drop_label(@store)}
            </p>
            <h1
              class="text-4xl sm:text-5xl lg:text-6xl text-white mb-4 leading-[0.95] uppercase tracking-[-0.01em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              {@product.title}
            </h1>
            <p
              class="text-2xl text-[var(--theme-accent,#00FF85)] mb-6 tabular-nums"
              style="font-family: 'JetBrains Mono', monospace;"
            >
              {format_price(@price, @store.currency)}
            </p>

            <p
              :if={@product.description}
              class="text-sm sm:text-base text-[#A3A3A3] leading-relaxed mb-8"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.description}
            </p>

            <%!-- Option pickers ── --%>
            <div :if={@option_types != []} class="space-y-5 mb-8">
              <div :for={option_type <- @option_types}>
                <p
                  class="text-[10px] font-bold tracking-[0.3em] uppercase text-white mb-2"
                  style="font-family: 'Space Grotesk', sans-serif;"
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
                      "min-w-[44px] inline-flex items-center justify-center px-4 py-2.5 text-xs uppercase tracking-[0.15em] transition-colors",
                      if(option_value_selected?(@selected_options, option_type.id, value.id),
                        do:
                          "bg-[var(--theme-accent,#00FF85)] text-[#0A0A0A] border border-[var(--theme-accent,#00FF85)]",
                        else: "bg-[#1F1F1F] text-white border border-[#262626] hover:border-white"
                      )
                    ]}
                    style="font-family: 'Space Grotesk', sans-serif;"
                  >
                    {value.value}
                  </button>
                </div>
              </div>
            </div>

            <%!-- CTA ── --%>
            <button
              type="button"
              phx-click="add_to_cart"
              class="w-full flex items-center justify-center gap-2 py-4 px-6 bg-[var(--theme-accent,#00FF85)] text-[#0A0A0A] text-[11px] font-bold uppercase tracking-[0.3em] hover:bg-[#00CC6A] active:scale-[0.99] transition-all mb-3"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Cop · {format_price(line_total(@price, @quantity), @store.currency)}
            </button>
            <p
              class="text-[10px] uppercase tracking-[0.25em] text-[#A3A3A3] mb-10 text-center"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Limited run · No restocks
            </p>

            <%!-- Sparse details ── --%>
            <div class="space-y-px border-y border-[#262626]">
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-[11px] uppercase tracking-[0.25em] text-white"
                  style="font-family: 'Space Grotesk', sans-serif;"
                >
                  Materials
                  <span class="material-symbols-outlined text-[18px] text-[#A3A3A3] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#A3A3A3]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  100% organic cotton. Garment-dyed. Pre-shrunk.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-[11px] uppercase tracking-[0.25em] text-white border-t border-[#262626]"
                  style="font-family: 'Space Grotesk', sans-serif;"
                >
                  Fit
                  <span class="material-symbols-outlined text-[18px] text-[#A3A3A3] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#A3A3A3]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Boxy oversize fit. Size up for relaxed, true to size for streetwear.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-[11px] uppercase tracking-[0.25em] text-white border-t border-[#262626]"
                  style="font-family: 'Space Grotesk', sans-serif;"
                >
                  Shipping & returns
                  <span class="material-symbols-outlined text-[18px] text-[#A3A3A3] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#A3A3A3]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Ships in 3-5 days within Ghana. Final sale on drop pieces.
                </div>
              </details>
            </div>
          </div>
        </div>

        <%!-- More drops ── --%>
        <section :if={@related_products != []} class="mt-20 sm:mt-28">
          <div class="mb-8 sm:mb-10">
            <h2
              class="text-3xl sm:text-4xl text-white uppercase tracking-[0.02em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              More from this drop
            </h2>
          </div>
          <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 lg:grid-cols-4 lg:gap-5">
            <Shared.drop_card
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

  defp format_price(nil, _currency), do: "—"

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

  defp drop_label(_store), do: "04"
end
