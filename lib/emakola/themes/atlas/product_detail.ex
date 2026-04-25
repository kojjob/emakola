defmodule Emakola.Themes.Atlas.ProductDetail do
  @moduledoc """
  Atlas theme PDP — sidebar-led catalog with two-column product layout.
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Atlas.Shared
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
    <div class="min-h-screen bg-[#FAFAFA] text-[#0F172A]">
      <Shared.theme_styles theme={@theme} />
      <Shared.atlas_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <div class="flex">
        <Shared.sidebar store={@store} categories={@categories} />

        <div class="flex-1 min-w-0">
          <main class="max-w-[1100px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-10">
            <nav
              class="flex items-center gap-2 mb-6 text-sm text-[#64748B]"
              style="font-family: 'Inter', sans-serif;"
              aria-label="Breadcrumb"
            >
              <a href={"/s/#{@store.slug}"} class="hover:text-[#0F172A] transition-colors">
                {@store.name}
              </a>
              <span class="text-[#CBD5E1]">/</span>
              <a href={"/s/#{@store.slug}/products"} class="hover:text-[#0F172A] transition-colors">
                All products
              </a>
              <span class="text-[#CBD5E1]">/</span>
              <span class="text-[#0F172A] font-medium truncate">{@product.title}</span>
            </nav>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12">
              <%!-- Image gallery ── --%>
              <div>
                <div class="aspect-square bg-white rounded-2xl border border-[#E2E8F0] flex items-center justify-center p-8 mb-3 overflow-hidden">
                  <%= if @current_image do %>
                    <.optimized_image
                      src={@current_image}
                      alt={@product.title}
                      priority={:high}
                      class="max-w-full max-h-full object-contain"
                    />
                  <% else %>
                    <span class="material-symbols-outlined text-7xl text-[#CBD5E1]">
                      shopping_bag
                    </span>
                  <% end %>
                </div>

                <div :if={length(@images) > 1} class="grid grid-cols-4 gap-2">
                  <a
                    :for={{src, idx} <- Enum.with_index(Enum.take(@images, 4))}
                    href={"?image=#{idx}"}
                    class={[
                      "block aspect-square rounded-lg overflow-hidden border-2 transition-colors bg-white p-2",
                      if(idx == @current_image_index,
                        do: "border-[var(--theme-accent,#2563EB)]",
                        else: "border-[#E2E8F0] hover:border-[#94A3B8]"
                      )
                    ]}
                  >
                    <.optimized_image
                      src={src}
                      alt={"#{@product.title} view #{idx + 1}"}
                      priority={:low}
                      class="w-full h-full object-contain"
                    />
                  </a>
                </div>
              </div>

              <%!-- Product info ── --%>
              <div>
                <h1
                  class="text-3xl sm:text-4xl font-bold text-[#0F172A] mb-3 leading-tight"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {@product.title}
                </h1>
                <p
                  class="inline-flex items-center px-3.5 py-1 rounded-full bg-[#EC4899] text-white text-sm font-semibold tabular-nums mb-6"
                  style="font-family: 'JetBrains Mono', monospace;"
                >
                  {format_price(@price, @store.currency)}
                </p>

                <p
                  :if={@product.description}
                  class="text-base text-[#475569] leading-relaxed mb-6"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {@product.description}
                </p>

                <%!-- Option pickers ── --%>
                <div :if={@option_types != []} class="space-y-5 mb-6">
                  <div :for={option_type <- @option_types}>
                    <p
                      class="text-xs font-semibold text-[#64748B] mb-2 uppercase tracking-wide"
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
                          "min-w-[44px] inline-flex items-center justify-center px-4 py-2.5 rounded-full text-xs font-medium transition-colors",
                          if(option_value_selected?(@selected_options, option_type.id, value.id),
                            do: "bg-[#0F172A] text-white border-2 border-[#0F172A]",
                            else:
                              "bg-white text-[#0F172A] border-2 border-[#E2E8F0] hover:border-[var(--theme-accent,#2563EB)]"
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
                    class="w-full flex items-center justify-center py-3.5 px-6 bg-[#0F172A] text-white text-sm font-semibold rounded-full hover:bg-[#1E293B] active:scale-[0.99] transition-all"
                    style="font-family: 'Inter', sans-serif;"
                  >
                    Add to bag · {format_price(line_total(@price, @quantity), @store.currency)}
                  </button>
                  <button
                    type="button"
                    class="w-full flex items-center justify-center py-3 px-6 text-sm font-medium text-[#0F172A] border border-[#E2E8F0] rounded-full hover:border-[var(--theme-accent,#2563EB)] transition-colors"
                    style="font-family: 'Inter', sans-serif;"
                  >
                    Add to wishlist
                  </button>
                </div>

                <%!-- Service strip ── --%>
                <div class="grid grid-cols-3 gap-3 py-4 border-y border-[#E2E8F0] text-center">
                  <div>
                    <span class="material-symbols-outlined text-[20px] text-[var(--theme-accent,#2563EB)] block mb-1">
                      local_shipping
                    </span>
                    <p class="text-[11px] text-[#64748B]" style="font-family: 'Inter', sans-serif;">
                      Free shipping
                    </p>
                  </div>
                  <div>
                    <span class="material-symbols-outlined text-[20px] text-[var(--theme-accent,#2563EB)] block mb-1">
                      cached
                    </span>
                    <p class="text-[11px] text-[#64748B]" style="font-family: 'Inter', sans-serif;">
                      14-day returns
                    </p>
                  </div>
                  <div>
                    <span class="material-symbols-outlined text-[20px] text-[var(--theme-accent,#2563EB)] block mb-1">
                      verified
                    </span>
                    <p class="text-[11px] text-[#64748B]" style="font-family: 'Inter', sans-serif;">
                      Authentic
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <section :if={@related_products != []} class="mt-16">
              <h2
                class="text-lg font-bold text-[#0F172A] mb-5"
                style="font-family: 'Inter', sans-serif;"
              >
                You may also like
              </h2>
              <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 sm:gap-4">
                <Shared.shelf_card
                  :for={{related, idx} <- Enum.with_index(Enum.take(@related_products, 4))}
                  product={related}
                  store={@store}
                  color_index={idx + 1}
                />
              </div>
            </section>
          </main>
        </div>
      </div>

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
end
