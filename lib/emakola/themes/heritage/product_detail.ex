defmodule Emakola.Themes.Heritage.ProductDetail do
  @moduledoc """
  Heritage theme product detail page (PDP) — built for crafted goods.

  Layout:
    * Sticky Heritage nav + warm breadcrumb
    * Two-column desktop: image gallery (left, 60%) + sticky info (right, 40%)
    * Lora serif title, clay price
    * Maker provenance pill above title ("Made in [city] · By [maker]")
    * Variant pickers — soft pills
    * Quantity stepper + dual CTA: Add to bag (clay) + Speak to a maker (sage outlined)
    * Native <details> accordions: Materials · Care · Provenance · Shipping
    * "From the same maker" cross-sell strip
    * Heritage footer
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Heritage.Shared
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
      <Shared.heritage_nav store={@store} cart_count={@cart_count} />

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-6">
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-[10px] uppercase tracking-[0.25em] text-[#78716C] hover:text-[var(--theme-primary,#A0522D)] transition-colors inline-flex items-center gap-1.5"
          style="font-family: 'Inter', sans-serif;"
        >
          ← Back to the workshop
        </a>
      </div>

      <main class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-12">
        <div class="grid grid-cols-1 lg:grid-cols-[60%_40%] gap-8 lg:gap-14">
          <%!-- Image gallery ── --%>
          <div>
            <div class="aspect-square bg-[#F4E4C1]/30 rounded-2xl overflow-hidden mb-3">
              <%= if @current_image do %>
                <.optimized_image
                  src={@current_image}
                  alt={@product.title}
                  priority={:high}
                  class="w-full h-full object-cover"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <span class="material-symbols-outlined text-7xl text-[var(--theme-primary,#A0522D)]/40">
                    chair
                  </span>
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
                    do: "border-[var(--theme-primary,#A0522D)]",
                    else: "border-transparent hover:border-[#E7DDC7]"
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
          <div class="lg:sticky lg:top-28 lg:self-start">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
              {provenance_kicker(@store)}
            </p>
            <h1
              class="text-3xl sm:text-4xl lg:text-5xl text-[#1C1917] mb-4 leading-[1.1]"
              style="font-family: 'Lora', serif;"
            >
              {@product.title}
            </h1>
            <p
              class="text-xl text-[var(--theme-primary,#A0522D)] mb-6 tabular-nums"
              style="font-family: 'Inter', sans-serif;"
            >
              {format_price(@price, @store.currency)}
            </p>

            <p
              :if={@product.description}
              class="text-base text-[#57534E] leading-relaxed mb-8"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.description}
            </p>

            <%!-- Maker provenance card ── --%>
            <div class="rounded-2xl bg-[#F4E4C1]/40 border border-[#E7DDC7] p-5 mb-8 flex items-start gap-3">
              <span class="flex-shrink-0 w-10 h-10 rounded-full bg-[var(--theme-primary,#A0522D)] flex items-center justify-center">
                <span class="material-symbols-outlined text-[20px] text-white">handyman</span>
              </span>
              <div class="min-w-0">
                <p
                  class="text-[10px] font-medium tracking-[0.25em] uppercase text-[var(--theme-accent,#84A98C)] mb-1"
                  style="font-family: 'Inter', sans-serif;"
                >
                  By the maker
                </p>
                <p
                  class="text-sm text-[#1C1917]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Hand-built by {@store.name}<span :if={maker_location(@store) != ""}>, {maker_location(@store)}</span>. Each piece carries marginal variation — a record of the hand that made it.
                </p>
              </div>
            </div>

            <%!-- Option pickers ── --%>
            <div :if={@option_types != []} class="space-y-5 mb-6">
              <div :for={option_type <- @option_types}>
                <p
                  class="text-[10px] font-medium tracking-[0.25em] uppercase text-[#1C1917] mb-2"
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
                      "inline-flex items-center px-4 py-2.5 rounded-full text-xs uppercase tracking-[0.15em] transition-all",
                      if(option_value_selected?(@selected_options, option_type.id, value.id),
                        do:
                          "bg-[var(--theme-primary,#A0522D)] text-white border-2 border-[var(--theme-primary,#A0522D)]",
                        else:
                          "bg-white text-[#78716C] border-2 border-[#E7DDC7] hover:border-[var(--theme-primary,#A0522D)]"
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
                class="text-[10px] font-medium tracking-[0.25em] uppercase text-[#1C1917]"
                style="font-family: 'Inter', sans-serif;"
              >
                Quantity
              </p>
              <div class="inline-flex items-center bg-white border-2 border-[#E7DDC7] rounded-full overflow-hidden">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  class="w-10 h-10 flex items-center justify-center text-[#78716C] hover:bg-[#F4E4C1]/40 transition-colors disabled:opacity-30"
                  disabled={@quantity <= 1}
                  aria-label="Decrease quantity"
                >
                  <span class="material-symbols-outlined text-[20px]">remove</span>
                </button>
                <span
                  class="w-10 text-center text-base font-medium text-[#1C1917] tabular-nums"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {@quantity}
                </span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  class="w-10 h-10 flex items-center justify-center text-[#78716C] hover:bg-[#F4E4C1]/40 transition-colors"
                  aria-label="Increase quantity"
                >
                  <span class="material-symbols-outlined text-[20px]">add</span>
                </button>
              </div>
            </div>

            <%!-- CTA ── --%>
            <div class="space-y-3 mb-10">
              <button
                type="button"
                phx-click="add_to_cart"
                class="w-full flex items-center justify-center gap-2 py-4 px-6 bg-[var(--theme-primary,#A0522D)] text-white rounded-full text-sm font-medium hover:bg-[#7C3F22] active:scale-[0.97] transition-all shadow-md"
                style="font-family: 'Inter', sans-serif;"
              >
                Add to bag · {format_price(line_total(@price, @quantity), @store.currency)}
              </button>
              <a
                :if={Map.get(@store, :whatsapp_number)}
                href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
                target="_blank"
                rel="noopener noreferrer"
                class="w-full flex items-center justify-center gap-2 py-3.5 px-6 text-sm font-medium text-[var(--theme-accent,#84A98C)] border-2 border-[var(--theme-accent,#84A98C)] rounded-full hover:bg-[var(--theme-accent,#84A98C)] hover:text-white transition-all"
                style="font-family: 'Inter', sans-serif;"
              >
                Speak to a maker
              </a>
            </div>

            <%!-- Accordions ── --%>
            <div class="space-y-px border-y border-[#E7DDC7]">
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-sm text-[#1C1917]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Materials
                  <span class="material-symbols-outlined text-[18px] text-[#78716C] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#78716C] leading-relaxed"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Local hardwood, natural finishes, hand-applied beeswax. Materials sourced within
                  the region wherever possible.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-sm text-[#1C1917] border-t border-[#E7DDC7]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Care
                  <span class="material-symbols-outlined text-[18px] text-[#78716C] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#78716C] leading-relaxed"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Wipe with a damp cloth. Re-oil annually with our care kit. We offer free
                  restoration on pieces sold within the past five years.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-sm text-[#1C1917] border-t border-[#E7DDC7]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Provenance
                  <span class="material-symbols-outlined text-[18px] text-[#78716C] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#78716C] leading-relaxed"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Made by hand in our workshop. Every piece is signed and dated by the maker.
                </div>
              </details>
              <details class="group">
                <summary
                  class="cursor-pointer list-none px-1 py-5 flex items-center justify-between text-sm text-[#1C1917] border-t border-[#E7DDC7]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Shipping & returns
                  <span class="material-symbols-outlined text-[18px] text-[#78716C] group-open:rotate-180 transition-transform">
                    expand_more
                  </span>
                </summary>
                <div
                  class="px-1 pb-5 text-sm text-[#78716C] leading-relaxed"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Hand-delivered within Accra; 5–10 day shipping elsewhere. 30-day returns on
                  unused pieces.
                </div>
              </details>
            </div>
          </div>
        </div>

        <%!-- From the same maker ── --%>
        <section :if={@related_products != []} class="mt-20 sm:mt-28">
          <div class="mb-10 text-center">
            <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
              From the same hands
            </p>
            <h2
              class="text-3xl sm:text-4xl text-[#1C1917]"
              style="font-family: 'Lora', serif;"
            >
              From the same maker
            </h2>
          </div>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-6 lg:grid-cols-4 lg:gap-8">
            <Shared.craft_card
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

  defp provenance_kicker(store) do
    case maker_location(store) do
      "" -> "Hand-built piece"
      loc -> "Made in #{loc}"
    end
  end

  defp maker_location(store) do
    [Map.get(store, :city), Map.get(store, :region)]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end
end
