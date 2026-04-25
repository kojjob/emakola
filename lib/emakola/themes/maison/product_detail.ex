defmodule Emakola.Themes.Maison.ProductDetail do
  @moduledoc """
  Maison theme product detail page (PDP) — built for premium fashion.

  Layout:
    * Sticky Maison nav + sparse breadcrumb
    * Two-column desktop: vertical-scroll image gallery (left, 60%) +
      sticky product info (right, 40%)
    * Italic Playfair title, simple price line, no scarcity chips
    * Variant pickers — minimal squares for size, dot row for colour
    * Single primary CTA (Add to bag) + ghost concierge link
    * Sparse details — Composition · Care · Provenance · Shipping
      as native <details> accordions, low-contrast borders
    * "Also seen with" cross-sell strip — three pieces, no labels
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Maison.Shared
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
      |> assign_new(:price, fn ->
        active_price(assigns.product, assigns.selected_variant)
      end)

    ~H"""
    <div class="min-h-screen bg-white">
      <Shared.theme_styles theme={@theme} />
      <Shared.maison_nav store={@store} cart_count={@cart_count} />

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-6">
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-[10px] uppercase tracking-[0.25em] text-[#78716C] hover:text-[#1C1917] transition-colors inline-flex items-center gap-1.5"
          style="font-family: 'Inter', sans-serif;"
        >
          ← The collection
        </a>
      </div>

      <main class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8 lg:py-12">
        <div class="grid grid-cols-1 lg:grid-cols-[60%_40%] gap-8 lg:gap-16">
          <%!-- Image gallery — vertical stack on desktop ── --%>
          <div>
            <%= if @images == [] do %>
              <div class="aspect-[3/4] bg-[#F5F5F4] flex items-center justify-center">
                <span class="material-symbols-outlined text-7xl text-[#A8A29E]">apparel</span>
              </div>
            <% else %>
              <div class="space-y-4 lg:space-y-6">
                <div
                  :for={{src, idx} <- Enum.with_index(@images)}
                  class="aspect-[3/4] bg-[#F5F5F4] overflow-hidden"
                >
                  <.optimized_image
                    src={src}
                    alt={"#{@product.title} view #{idx + 1}"}
                    priority={if(idx == 0, do: :high, else: :low)}
                    class="w-full h-full object-cover"
                  />
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Sticky product info ── --%>
          <div class="lg:sticky lg:top-28 lg:self-start">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-4">
              The piece
            </p>
            <h1
              class="text-3xl sm:text-4xl lg:text-5xl text-[#1C1917] mb-4 leading-[1.1] italic"
              style="font-family: 'Playfair Display', serif;"
            >
              {@product.title}
            </h1>
            <p
              class="text-base text-[#1C1917] mb-8 tabular-nums tracking-wide"
              style="font-family: 'Inter', sans-serif;"
            >
              {format_price(@price, @store.currency)}
            </p>

            <p
              :if={@product.description}
              class="text-sm sm:text-base text-[#78716C] leading-relaxed font-light mb-8"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.description}
            </p>

            <%!-- Option pickers ── --%>
            <div :if={@option_types != []} class="space-y-6 mb-8">
              <div :for={option_type <- @option_types}>
                <p
                  class="text-[10px] font-medium tracking-[0.25em] uppercase text-[#1C1917] mb-3"
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
                      "min-w-[44px] inline-flex items-center justify-center px-4 py-2.5 text-xs uppercase tracking-[0.15em] transition-all",
                      if(option_value_selected?(@selected_options, option_type.id, value.id),
                        do: "bg-[#1C1917] text-white border border-[#1C1917]",
                        else: "bg-white text-[#1C1917] border border-[#E7E5E4] hover:border-[#1C1917]"
                      )
                    ]}
                    style="font-family: 'Inter', sans-serif;"
                  >
                    {value.value}
                  </button>
                </div>
              </div>
            </div>

            <%!-- CTA — single primary, ghost concierge ── --%>
            <div class="space-y-3 mb-10">
              <button
                type="button"
                phx-click="add_to_cart"
                class="w-full flex items-center justify-center py-4 px-6 bg-[#1C1917] text-white text-[11px] uppercase tracking-[0.3em] hover:bg-[#292524] active:scale-[0.99] transition-all"
                style="font-family: 'Inter', sans-serif;"
              >
                Add to bag · {format_price(line_total(@price, @quantity), @store.currency)}
              </button>
              <a
                :if={Map.get(@store, :whatsapp_number)}
                href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
                target="_blank"
                rel="noopener noreferrer"
                class="w-full flex items-center justify-center py-3.5 px-6 text-[11px] uppercase tracking-[0.25em] text-[#1C1917] border border-[#E7E5E4] hover:border-[#1C1917] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Speak with the concierge
              </a>
            </div>

            <%!-- Sparse accordions ── --%>
            <div class="space-y-px border-y border-[#E7E5E4]">
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-[11px] uppercase tracking-[0.25em] text-[#1C1917] border-b border-[#E7E5E4] last:border-b-0"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Composition
                  <span class="material-symbols-outlined text-[18px] text-[#78716C] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#78716C] leading-relaxed font-light"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Hand-loomed cotton, finished by a small atelier. Each piece carries marginal
                  variation — a record of the hand that made it.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-[11px] uppercase tracking-[0.25em] text-[#1C1917] border-t border-[#E7E5E4]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Care
                  <span class="material-symbols-outlined text-[18px] text-[#78716C] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#78716C] leading-relaxed font-light"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Hand wash cold. Reshape and dry flat. Press on reverse with a low iron.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-[11px] uppercase tracking-[0.25em] text-[#1C1917] border-t border-[#E7E5E4]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Provenance
                  <span class="material-symbols-outlined text-[18px] text-[#78716C] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#78716C] leading-relaxed font-light"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Designed and produced in Accra. Materials sourced within the region wherever
                  possible. The maker's name and workshop are recorded with each piece.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-[11px] uppercase tracking-[0.25em] text-[#1C1917] border-t border-[#E7E5E4]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Shipping & returns
                  <span class="material-symbols-outlined text-[18px] text-[#78716C] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#78716C] leading-relaxed font-light"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Complimentary shipping within Ghana. International by quotation.
                  14-day returns on unworn, unaltered pieces.
                </div>
              </details>
            </div>
          </div>
        </div>

        <%!-- Also seen with ── --%>
        <section :if={@related_products != []} class="mt-24 sm:mt-32">
          <div class="mb-10 sm:mb-14 text-center">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-3">
              In conversation
            </p>
            <h2
              class="text-3xl sm:text-4xl text-[#1C1917] italic"
              style="font-family: 'Playfair Display', serif;"
            >
              Also seen with
            </h2>
          </div>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-8 lg:gap-10">
            <Shared.portrait_card
              :for={related <- Enum.take(@related_products, 3)}
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

  defp format_price(nil, _currency), do: "Price by enquiry"

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

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end
end
