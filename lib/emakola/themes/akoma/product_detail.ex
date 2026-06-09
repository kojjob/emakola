defmodule Emakola.Themes.Akoma.ProductDetail do
  @moduledoc """
  Akoma product detail — Be Yours–style two-column: sticky gallery + details,
  pill option selectors, qty stepper, near-black Add to cart + WhatsApp order,
  JS accordions, sticky mobile bar, "Pair it with", and reviews.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias Emakola.Themes.Akoma.Shared

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

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
    assigns =
      assigns
      |> assign(:price, price_for(assigns.product, assigns.selected_variant))
      |> assign(:compare_at, compare_at(assigns.selected_variant))
      |> assign(:currency, Map.get(assigns.store, :currency, "GHS"))
      |> assign(:wa_link, Shared.whatsapp_link(assigns.store, assigns.product.title))

    ~H"""
    <div class="akoma-body min-h-screen pb-24 lg:pb-0">
      <Shared.theme_styles theme={@theme} />
      <Shared.akoma_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumb --%>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-6">
        <nav class="flex items-center gap-2 text-xs text-[#9CA3AF]">
          <a href={"/s/#{@store.slug}"} class="hover:text-[#1A1A1A]">Home</a>
          <span>/</span>
          <a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">Shop</a>
          <span>/</span>
          <span class="text-[#1A1A1A] truncate max-w-[180px]">{@product.title}</span>
        </nav>
      </div>

      <%!-- Main --%>
      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8 lg:py-12">
        <div class="grid lg:grid-cols-[1.1fr_1fr] gap-8 lg:gap-14">
          <%!-- Gallery --%>
          <div class="flex gap-3">
            <div :if={length(@product.images) > 1} class="hidden sm:flex flex-col gap-2 w-16 shrink-0">
              <button
                :for={{image, idx} <- Enum.with_index(@product.images)}
                type="button"
                phx-click="select_image"
                phx-value-index={idx}
                class={"akoma-card aspect-[3/4] overflow-hidden " <>
                  if(idx == @current_image_index, do: "ring-2 ring-[#1A1A1A]", else: "opacity-70 hover:opacity-100")}
              >
                <img
                  src={Map.get(image, :thumbnail_url) || Map.get(image, :url)}
                  alt={"#{@product.title} #{idx + 1}"}
                  class="w-full h-full object-cover"
                />
              </button>
            </div>
            <div class="flex-1 akoma-card aspect-[3/4] overflow-hidden relative">
              <span
                :if={on_sale?(@price, @compare_at)}
                class="absolute top-3 left-3 z-10 bg-[#1A1A1A] text-white text-[10px] font-semibold tracking-wider px-2.5 py-1"
              >
                SALE
              </span>
              <.optimized_image
                :if={Shared.current_image(@product, @current_image_index)}
                src={Shared.current_image(@product, @current_image_index)}
                alt={@product.title}
                class="w-full h-full object-cover"
              />
              <div
                :if={!Shared.current_image(@product, @current_image_index)}
                class="w-full h-full flex items-center justify-center bg-[#F0F1EF]"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-24 h-24 text-[#CBD5C7]"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
                </svg>
              </div>
            </div>
          </div>

          <%!-- Info --%>
          <div class="lg:sticky lg:top-24 lg:self-start">
            <div class="text-[11px] uppercase tracking-[0.18em] text-[#9CA3AF]">{@store.name}</div>
            <h1 class="akoma-heading text-2xl sm:text-3xl font-bold text-[#1A1A1A] mt-2">
              {@product.title}
            </h1>

            <a
              :if={Map.get(@product, :review_count, 0) > 0}
              href="#akoma-reviews"
              class="inline-flex items-center gap-2 mt-2 text-xs text-[#6B7280]"
            >
              <span class="text-[#1A1A1A] tracking-tight">{stars(@product)}</span>
              <span>{format_rating(@product)} · {@product.review_count} reviews</span>
            </a>

            <div class="flex items-baseline gap-3 mt-4">
              <span class="text-2xl font-bold text-[#1A1A1A]">
                {EmakolaWeb.Helpers.Currency.format_price(@price, @currency)}
              </span>
              <span :if={on_sale?(@price, @compare_at)} class="text-sm text-[#9CA3AF] line-through">
                {EmakolaWeb.Helpers.Currency.format_price(@compare_at, @currency)}
              </span>
              <span
                :if={on_sale?(@price, @compare_at)}
                class="text-[11px] font-semibold text-[#B91C1C] bg-[#FDE2E2] px-2 py-0.5 rounded"
              >
                Save {discount_pct(@price, @compare_at)}%
              </span>
            </div>

            <%!-- Option pills --%>
            <div :if={@option_types != []} class="space-y-5 mt-6">
              <div :for={option_type <- @option_types}>
                <div class="text-xs text-[#1A1A1A] mb-2">
                  {option_type.name}:
                  <span class="text-[#6B7280]">{selected_label(option_type, @selected_options)}</span>
                </div>
                <div class="flex flex-wrap gap-2">
                  <button
                    :for={option_value <- option_type.option_values || []}
                    type="button"
                    phx-click="select_option"
                    phx-value-option_type_id={option_type.id}
                    phx-value-value={option_value.id}
                    class={"min-w-[44px] min-h-[44px] px-4 py-2 text-sm rounded-md border transition-colors " <>
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do: "border-[#2F5D50] bg-[#2F5D50] text-white font-medium",
                        else: "border-[#E8EAE7] bg-white text-[#1A1A1A] hover:border-[#2F5D50]")}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </div>

            <%!-- Qty + stock --%>
            <div class="flex items-center gap-4 mt-6">
              <div class="flex items-center border border-[#E8EAE7] rounded-md">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  class="w-10 h-10 flex items-center justify-center text-[#1A1A1A]"
                  aria-label="Decrease"
                >
                  −
                </button>
                <span class="w-10 text-center text-sm font-medium">{@quantity}</span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  class="w-10 h-10 flex items-center justify-center text-[#1A1A1A]"
                  aria-label="Increase"
                >
                  +
                </button>
              </div>
              <span class="text-xs" style={"color: #{stock_color(@selected_variant)}"}>
                {stock_label(@selected_variant)}
              </span>
            </div>

            <%!-- CTAs --%>
            <button
              type="button"
              phx-click="add_to_cart"
              disabled={!in_stock?(@selected_variant)}
              class={"w-full mt-4 py-3.5 rounded-md text-sm font-semibold uppercase tracking-wider transition-colors " <>
                if(in_stock?(@selected_variant),
                  do: "bg-[#1A1A1A] text-white hover:bg-[#2F5D50]",
                  else: "bg-[#E8EAE7] text-[#9CA3AF] cursor-not-allowed")}
            >
              {if in_stock?(@selected_variant), do: "Add to cart", else: "Out of stock"}
            </button>

            <a
              :if={@wa_link}
              href={@wa_link}
              target="_blank"
              rel="noopener"
              class="w-full mt-3 py-3 rounded-md border border-[#25D366] text-[#128C3A] text-sm font-semibold flex items-center justify-center gap-2 hover:bg-[#25D366]/5"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class="w-4 h-4"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M12 2a10 10 0 0 0-8.5 15.3L2 22l4.8-1.5A10 10 0 1 0 12 2Zm5.3 13.9c-.2.6-1.3 1.2-1.8 1.2-.5.1-1 .2-3.3-.7-2.8-1.1-4.5-3.9-4.7-4.1-.1-.2-1-1.4-1-2.6 0-1.3.6-1.9.9-2.1.2-.3.5-.3.7-.3h.5c.2 0 .4 0 .6.5l.8 1.9c.1.2.1.4 0 .5l-.4.5c-.2.2-.3.4-.1.7.2.3.8 1.3 1.7 2.1 1.2 1 2.1 1.4 2.4 1.5.2.1.4.1.6-.1l.7-.9c.2-.2.4-.2.6-.1l1.8.9c.2.1.4.2.5.3.1.2.1.6-.1 1.1Z" />
              </svg>
              Order on WhatsApp
            </a>

            <%!-- Accordions --%>
            <div class="mt-6 border-t border-[#E8EAE7]">
              <div class="border-b border-[#E8EAE7]">
                <button
                  type="button"
                  phx-click={JS.toggle(to: "#akoma-acc-desc")}
                  class="w-full flex items-center justify-between py-3.5 text-sm text-[#1A1A1A]"
                >
                  Description <span>−</span>
                </button>
                <div id="akoma-acc-desc" class="pb-4 text-sm text-[#6B7280] leading-relaxed">
                  {@product.description || "A well-made product, fairly priced."}
                </div>
              </div>
              <div class="border-b border-[#E8EAE7]">
                <button
                  type="button"
                  phx-click={JS.toggle(to: "#akoma-acc-ship")}
                  class="w-full flex items-center justify-between py-3.5 text-sm text-[#1A1A1A]"
                >
                  Delivery &amp; returns <span>+</span>
                </button>
                <div id="akoma-acc-ship" class="hidden pb-4 text-sm text-[#6B7280] leading-relaxed">
                  Next-day delivery across Accra, nationwide in 2–4 days. Easy returns within 7 days.
                </div>
              </div>
            </div>

            <%!-- Trust --%>
            <div class="flex flex-wrap gap-x-5 gap-y-2 mt-5 text-[11px] text-[#9CA3AF]">
              <span>🔒 Secure checkout</span>
              <span>📱 MoMo &amp; Paystack</span>
              <span>🚚 Local delivery</span>
            </div>
          </div>
        </div>
      </section>

      <%!-- Pair it with --%>
      <section
        :if={@related_products != []}
        class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 border-t border-[#E8EAE7]"
      >
        <h2 class="akoma-heading text-lg font-bold text-[#1A1A1A] mb-6">Pair it with</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6">
          <Shared.product_card
            :for={product <- Enum.take(@related_products, 4)}
            product={product}
            store={@store}
          />
        </div>
      </section>

      <%!-- Reviews (only when the LiveView provides review assigns) --%>
      <section
        :if={assigns[:reviews] != nil}
        id="akoma-reviews"
        class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 border-t border-[#E8EAE7]"
      >
        <EmakolaWeb.ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={assigns[:reviews] || []}
          can_review={assigns[:can_review] || false}
          already_reviewed={assigns[:already_reviewed] || false}
          review_form_rating={assigns[:review_form_rating] || 0}
          review_form_title={assigns[:review_form_title] || ""}
          review_form_body={assigns[:review_form_body] || ""}
          review_submitting={assigns[:review_submitting] || false}
          avg_rating={Map.get(@product, :avg_rating)}
          review_count={Map.get(@product, :review_count, 0)}
          uploads={assigns[:uploads]}
        />
      </section>

      <%!-- Sticky mobile add-to-cart bar --%>
      <div class="fixed bottom-0 inset-x-0 z-40 lg:hidden bg-white border-t border-[#E8EAE7] px-4 py-3 flex items-center justify-between gap-3">
        <div class="min-w-0">
          <div class="text-xs font-medium text-[#1A1A1A] truncate">{@product.title}</div>
          <div class="text-sm font-bold text-[#2F5D50]">
            {EmakolaWeb.Helpers.Currency.format_price(@price, @currency)}
          </div>
        </div>
        <button
          type="button"
          phx-click="add_to_cart"
          disabled={!in_stock?(@selected_variant)}
          class={"shrink-0 px-6 py-3 rounded-md text-sm font-semibold uppercase tracking-wider " <>
            if(in_stock?(@selected_variant), do: "bg-[#1A1A1A] text-white", else: "bg-[#E8EAE7] text-[#9CA3AF]")}
        >
          {if in_stock?(@selected_variant), do: "Add", else: "Sold out"}
        </button>
      </div>

      <Shared.akoma_footer store={@store} />
    </div>
    """
  end

  # ── Helpers ──

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0

  defp compare_at(%{compare_at_price: cap}) when is_integer(cap), do: cap
  defp compare_at(_), do: nil

  defp on_sale?(price, compare_at) when is_integer(compare_at), do: compare_at > price
  defp on_sale?(_, _), do: false

  defp discount_pct(price, compare_at) when is_integer(compare_at) and compare_at > 0 do
    round((compare_at - price) / compare_at * 100)
  end

  defp discount_pct(_, _), do: 0

  defp in_stock?(%{stock_quantity: q}) when is_integer(q), do: q > 0
  defp in_stock?(_), do: true

  defp stock_label(%{stock_quantity: q}) when is_integer(q) and q <= 0, do: "Out of stock"

  defp stock_label(%{stock_quantity: q}) when is_integer(q) and q <= 5,
    do: "Only #{q} left in stock"

  defp stock_label(_), do: "In stock"

  defp stock_color(%{stock_quantity: q}) when is_integer(q) and q <= 0, do: "#B91C1C"
  defp stock_color(_), do: "#16A34A"

  defp selected_label(option_type, selected_options) do
    selected_id = Map.get(selected_options, option_type.id)

    case Enum.find(option_type.option_values || [], &(&1.id == selected_id)) do
      %{value: v} -> v
      _ -> "Select"
    end
  end

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

    String.duplicate("★", n) <> String.duplicate("☆", 5 - n)
  end
end
