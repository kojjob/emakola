defmodule Emakola.Themes.Circuit.ProductDetail do
  @moduledoc """
  Circuit theme PDP — minimal tech retail. Spec table is content.
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Circuit.Shared
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
    <div class="min-h-screen bg-[#0F0F12] text-white">
      <Shared.theme_styles theme={@theme} />
      <Shared.circuit_nav store={@store} cart_count={@cart_count} />

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-6">
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-sm text-[#9CA3AF] hover:text-white transition-colors inline-flex items-center gap-1.5"
          style="font-family: 'Inter', sans-serif;"
        >
          ← All devices
        </a>
      </div>

      <main class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-12">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-14">
          <%!-- Image gallery ── --%>
          <div>
            <div class="aspect-square bg-[#1A1A1F] rounded-3xl overflow-hidden mb-3">
              <%= if @current_image do %>
                <.optimized_image
                  src={@current_image}
                  alt={@product.title}
                  priority={:high}
                  class="w-full h-full object-cover"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <span class="material-symbols-outlined text-7xl text-[#3F3F46]">smartphone</span>
                </div>
              <% end %>
            </div>

            <div :if={length(@images) > 1} class="grid grid-cols-4 gap-2 sm:gap-3">
              <a
                :for={{src, idx} <- Enum.with_index(Enum.take(@images, 4))}
                href={"?image=#{idx}"}
                class={[
                  "block aspect-square rounded-2xl overflow-hidden border-2 transition-colors",
                  if(idx == @current_image_index,
                    do: "border-[var(--theme-accent,#3B82F6)]",
                    else: "border-transparent hover:border-[#27272A]"
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
            <h1
              class="text-4xl sm:text-5xl lg:text-6xl text-white font-semibold tracking-tight mb-4 leading-[1.05]"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.title}
            </h1>
            <p
              class="text-2xl text-white mb-6 tabular-nums"
              style="font-family: 'JetBrains Mono', monospace;"
            >
              {format_price(@price, @store.currency)}
            </p>

            <p
              :if={@product.description}
              class="text-base text-[#9CA3AF] leading-relaxed mb-8"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.description}
            </p>

            <%!-- Spec preview ── --%>
            <div class="rounded-2xl bg-[#1A1A1F] border border-[#27272A] p-5 mb-6">
              <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-accent,#3B82F6)] mb-3">
                Key specs
              </p>
              <dl class="space-y-2">
                <div class="grid grid-cols-3 gap-3 text-sm">
                  <dt class="text-[#9CA3AF]" style="font-family: 'Inter', sans-serif;">Display</dt>
                  <dd
                    class="col-span-2 text-white"
                    style="font-family: 'JetBrains Mono', monospace;"
                  >
                    6.7" OLED · 120Hz
                  </dd>
                </div>
                <div class="grid grid-cols-3 gap-3 text-sm">
                  <dt class="text-[#9CA3AF]" style="font-family: 'Inter', sans-serif;">Storage</dt>
                  <dd
                    class="col-span-2 text-white"
                    style="font-family: 'JetBrains Mono', monospace;"
                  >
                    256 GB
                  </dd>
                </div>
                <div class="grid grid-cols-3 gap-3 text-sm">
                  <dt class="text-[#9CA3AF]" style="font-family: 'Inter', sans-serif;">
                    Connectivity
                  </dt>
                  <dd
                    class="col-span-2 text-white"
                    style="font-family: 'JetBrains Mono', monospace;"
                  >
                    5G · Wi-Fi 6E · USB-C
                  </dd>
                </div>
              </dl>
            </div>

            <%!-- Option pickers ── --%>
            <div :if={@option_types != []} class="space-y-5 mb-6">
              <div :for={option_type <- @option_types}>
                <p
                  class="text-xs font-semibold text-[#9CA3AF] mb-2"
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
                      "min-w-[44px] inline-flex items-center justify-center px-4 py-2.5 rounded-full text-xs font-medium transition-all",
                      if(option_value_selected?(@selected_options, option_type.id, value.id),
                        do: "bg-white text-[#0F0F12]",
                        else:
                          "bg-[#1A1A1F] text-white border border-[#27272A] hover:border-[var(--theme-accent,#3B82F6)]"
                      )
                    ]}
                    style="font-family: 'Inter', sans-serif;"
                  >
                    {value.value}
                  </button>
                </div>
              </div>
            </div>

            <%!-- CTA ── --%>
            <div class="space-y-3 mb-8">
              <button
                type="button"
                phx-click="add_to_cart"
                class="w-full flex items-center justify-center py-4 px-6 bg-[var(--theme-accent,#3B82F6)] text-white text-sm font-semibold rounded-full hover:bg-[#2563EB] active:scale-[0.99] transition-all"
                style="font-family: 'Inter', sans-serif;"
              >
                Add to bag · {format_price(line_total(@price, @quantity), @store.currency)}
              </button>
              <button
                type="button"
                class="w-full flex items-center justify-center py-3.5 px-6 text-sm font-medium text-white border border-[#27272A] rounded-full hover:border-[var(--theme-accent,#3B82F6)] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Compare device
              </button>
            </div>

            <%!-- Detail accordions ── --%>
            <div class="space-y-px border-y border-[#27272A]">
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-sm font-medium text-white"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Full specifications
                  <span class="material-symbols-outlined text-[18px] text-[#9CA3AF] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#9CA3AF]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Detailed spec sheet — chip, RAM, camera, battery, weight, dimensions — available
                  on request from our support team.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-sm font-medium text-white border-t border-[#27272A]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  In the box
                  <span class="material-symbols-outlined text-[18px] text-[#9CA3AF] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#9CA3AF]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Device · USB-C cable · Documentation · Warranty card.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-sm font-medium text-white border-t border-[#27272A]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Warranty & returns
                  <span class="material-symbols-outlined text-[18px] text-[#9CA3AF] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#9CA3AF]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Manufacturer warranty applies. 14-day return window from delivery date for
                  unopened devices.
                </div>
              </details>
            </div>
          </div>
        </div>

        <%!-- Related ── --%>
        <section :if={@related_products != []} class="mt-20 sm:mt-24">
          <h2
            class="text-3xl sm:text-4xl text-white font-semibold tracking-tight mb-10"
            style="font-family: 'Inter', sans-serif;"
          >
            You might also like
          </h2>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
            <Shared.device_card
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

  defp format_price(nil, _currency), do: "Out of stock"

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
