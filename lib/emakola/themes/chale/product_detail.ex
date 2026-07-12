defmodule Emakola.Themes.Chale.ProductDetail do
  @moduledoc """
  Chale theme — product detail page renderer.

  Square hard-framed gallery (placeholder-first), shouting price, and a
  legible size run: option values with no in-stock variant render struck
  through and named as sold out, because "does it come in my size, is it
  still there" is the whole question. Quantity stepper, add-to-cart,
  WhatsApp ask, promise-free policy links, related products, and the
  platform review section (when its assigns are present).
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Chale.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:vov_map, fn -> %{} end)
      |> assign_new(:reviews, fn -> nil end)
      |> assign(:whatsapp_href, Shared.whatsapp_link(assigns.store, assigns.product.title))
      |> assign(
        :purchasable,
        not is_nil(assigns.selected_variant) and
          Emakola.Catalog.Variant.in_stock?(assigns.selected_variant)
      )

    ~H"""
    <div class="min-h-screen bg-zinc-100">
      <Shared.theme_styles theme={@theme} />
      <%!-- Theme banner nav: the bottom bar below is mobile-only, so without
      this the cart would be unreachable from this page on desktop. --%>
      <Shared.chale_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <nav
        class="mx-auto hidden max-w-[1280px] px-4 py-4 sm:px-6 lg:block lg:px-8"
        aria-label="Breadcrumb"
      >
        <ol class="flex items-center gap-2 text-xs font-bold uppercase tracking-widest text-zinc-500">
          <li>
            <a
              href={store_path(@store.slug, "/")}
              class="hover:text-zinc-950 motion-safe:transition-colors"
            >
              Home
            </a>
          </li>
          <li aria-hidden="true">/</li>
          <li>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-zinc-950 motion-safe:transition-colors"
            >
              Shop
            </a>
          </li>
          <li aria-hidden="true">/</li>
          <li class="max-w-[240px] truncate text-zinc-950">{@product.title}</li>
        </ol>
      </nav>

      <div class="mx-auto max-w-[1280px] px-4 py-6 sm:px-6 lg:grid lg:grid-cols-2 lg:gap-12 lg:px-8">
        <%!-- Gallery: square, hard-framed, finished before the photo lands --%>
        <div class="lg:sticky lg:top-24 lg:self-start">
          <div class="relative aspect-square overflow-hidden border-2 border-zinc-950 bg-white shadow-[6px_6px_0_0_#09090B]">
            <div
              class="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-zinc-100 to-zinc-300"
              aria-hidden="true"
            >
              <span class="select-none text-9xl font-bold uppercase text-zinc-400 [font-family:var(--chale-display)]">
                {String.first(@product.title)}
              </span>
            </div>
            <.optimized_image
              :if={Shared.current_image(@product, @current_image_index)}
              src={Shared.current_image(@product, @current_image_index)}
              alt={"#{@product.title} — image #{@current_image_index + 1}"}
              priority={:high}
              width={640}
              height={640}
              class="absolute inset-0 h-full w-full object-cover"
            />
            <div
              :if={!Shared.current_image(@product, @current_image_index)}
              class="absolute bottom-3 left-3"
            >
              <Shared.price_stamp product={@product} store={@store} />
            </div>
          </div>

          <div
            :if={length(@product.images) > 1}
            class="mt-3 flex gap-2.5 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
            role="tablist"
            aria-label="Product images"
          >
            <button
              :for={{_image, index} <- Enum.with_index(@product.images)}
              type="button"
              phx-click="select_image"
              phx-value-index={index}
              role="tab"
              aria-selected={to_string(index == @current_image_index)}
              aria-label={"View image #{index + 1}"}
              class={[
                "h-16 w-16 flex-shrink-0 cursor-pointer overflow-hidden border-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2",
                if(index == @current_image_index,
                  do: "border-zinc-950",
                  else: "border-zinc-300 opacity-70 hover:border-zinc-950 hover:opacity-100"
                )
              ]}
            >
              <.optimized_image
                src={Shared.current_image(@product, index)}
                alt={"#{@product.title} thumbnail #{index + 1}"}
                priority={:low}
                width={64}
                height={64}
                class="h-full w-full object-cover"
              />
            </button>
          </div>
        </div>

        <%!-- Info column --%>
        <div class="mt-6 lg:mt-0">
          <span
            :if={Shared.new_arrival?(@product)}
            class="mb-3 inline-block -rotate-2 bg-store-accent px-2 py-1 text-[0.625rem] font-bold uppercase tracking-widest text-white"
          >
            Just dropped
          </span>

          <h1 class="text-3xl font-bold uppercase leading-[0.95] tracking-tight text-zinc-950 [font-family:var(--chale-display)] sm:text-4xl lg:text-5xl">
            {@product.title}
          </h1>

          <div class="mt-4 flex flex-wrap items-baseline gap-3">
            <p class="text-3xl font-bold tabular-nums tracking-tight text-zinc-950 [font-family:var(--chale-display)] sm:text-4xl">
              <%= if @selected_variant do %>
                {Currency.format_price(@selected_variant.price, @store.currency)}
              <% else %>
                {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
              <% end %>
            </p>
            <%= if @selected_variant && @selected_variant.compare_at_price &&
                  @selected_variant.compare_at_price > @selected_variant.price do %>
              <p class="text-lg tabular-nums text-zinc-500 line-through">
                {Currency.format_price(@selected_variant.compare_at_price, @store.currency)}
              </p>
              <span class="bg-store-accent px-2 py-1 text-xs font-bold uppercase tracking-wide text-white">
                Save {Currency.format_price(
                  @selected_variant.compare_at_price - @selected_variant.price,
                  @store.currency
                )}
              </span>
            <% end %>
          </div>

          <div class="mt-3">
            <.stock_line variant={@selected_variant} />
          </div>

          <p
            :if={@product.description}
            class="mt-4 text-[0.9375rem] leading-relaxed text-zinc-600"
          >
            {@product.description}
          </p>

          <%!-- The size run: availability is the whole question --%>
          <section
            :if={@option_types != []}
            class="mt-6 space-y-5"
            aria-label="Product options"
          >
            <div :for={option_type <- @option_types}>
              <p class="mb-2.5 text-xs font-bold uppercase tracking-widest text-zinc-950">
                {option_type.name}
              </p>
              <div
                class="flex flex-wrap gap-2"
                role="radiogroup"
                aria-label={"Select #{option_type.name}"}
              >
                <button
                  :for={option_value <- option_type.option_values}
                  type="button"
                  phx-click="select_option"
                  phx-value-option_type_id={option_type.id}
                  phx-value-value={option_value.id}
                  role="radio"
                  aria-checked={
                    to_string(Map.get(@selected_options, option_type.id) == option_value.id)
                  }
                  aria-label={
                    option_label(option_value.value, gone?(@product, @vov_map, option_value.id))
                  }
                  class={
                    option_tile_classes(
                      Map.get(@selected_options, option_type.id) == option_value.id,
                      gone?(@product, @vov_map, option_value.id)
                    )
                  }
                >
                  {option_value.value}
                </button>
              </div>
            </div>
          </section>

          <%!-- Quantity + add to cart --%>
          <div class="mt-6 flex items-center gap-3">
            <span class="text-xs font-bold uppercase tracking-widest text-zinc-950">Quantity</span>
            <div class="flex items-center border-2 border-zinc-950 bg-white">
              <button
                type="button"
                phx-click="decrement_quantity"
                disabled={@quantity <= 1}
                aria-label="Decrease quantity"
                class="flex h-11 w-11 cursor-pointer items-center justify-center text-zinc-950 hover:bg-zinc-100 disabled:cursor-not-allowed disabled:text-zinc-300 motion-safe:transition-colors"
              >
                <svg
                  class="h-4 w-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14" />
                </svg>
              </button>
              <span class="flex h-11 w-11 select-none items-center justify-center border-x-2 border-zinc-950 text-sm font-bold tabular-nums text-zinc-950">
                {@quantity}
              </span>
              <button
                type="button"
                phx-click="increment_quantity"
                disabled={@quantity >= 10}
                aria-label="Increase quantity"
                class="flex h-11 w-11 cursor-pointer items-center justify-center text-zinc-950 hover:bg-zinc-100 disabled:cursor-not-allowed disabled:text-zinc-300 motion-safe:transition-colors"
              >
                <svg
                  class="h-4 w-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
              </button>
            </div>
          </div>

          <button
            id="chale-add-to-cart"
            type="button"
            phx-click="add_to_cart"
            disabled={!@purchasable}
            class={[
              "mt-5 w-full px-6 py-4 text-sm font-bold uppercase tracking-widest",
              if(@purchasable,
                do:
                  "cursor-pointer border-2 border-zinc-950 bg-store-accent text-white shadow-[4px_4px_0_0_#09090B] hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:translate-y-0.5",
                else: "cursor-not-allowed border-2 border-zinc-300 bg-zinc-200 text-zinc-500"
              )
            ]}
          >
            {if @purchasable, do: "Add to cart", else: "Sold out"}
          </button>

          <a
            :if={@whatsapp_href}
            href={@whatsapp_href}
            target="_blank"
            rel="noopener noreferrer"
            class="mt-3 flex w-full items-center justify-center gap-2 border-2 border-zinc-950 bg-white px-6 py-3.5 text-sm font-bold uppercase tracking-widest text-zinc-950 hover:bg-zinc-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            <svg
              class="h-5 w-5 text-whatsapp"
              viewBox="0 0 24 24"
              fill="currentColor"
              aria-hidden="true"
            >
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
              <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
            </svg>
            Ask on WhatsApp
          </a>

          <p
            :if={@selected_variant && Map.get(@selected_variant, :sku)}
            class="mt-3 text-xs text-zinc-500"
          >
            SKU: {@selected_variant.sku}
          </p>

          <%!-- Promise-free: the merchant's own policies are authoritative --%>
          <div class="mt-6 border-t-2 border-zinc-950 pt-4 text-sm text-zinc-600">
            <p>
              Delivery &amp; returns —
              <a
                href={store_path(@store.slug, "/policies#shipping")}
                class="font-medium text-zinc-950 underline decoration-zinc-400 underline-offset-2 hover:decoration-zinc-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950"
              >
                see this store's policies
              </a>
            </p>
          </div>
        </div>
      </div>

      <%!-- Related products --%>
      <section
        :if={@related_products != []}
        class="mx-auto max-w-[1280px] px-4 py-8 sm:px-6 lg:px-8"
        aria-labelledby="chale-related-heading"
      >
        <h2
          id="chale-related-heading"
          class="mb-5 text-2xl font-bold uppercase tracking-tight text-zinc-950 [font-family:var(--chale-display)] sm:text-3xl"
        >
          More like this
        </h2>
        <div class="grid grid-cols-2 gap-4 sm:gap-5 lg:grid-cols-4 lg:gap-6">
          <Shared.product_card
            :for={related <- Enum.take(@related_products, 4)}
            product={related}
            store={@store}
          />
        </div>
      </section>

      <%!-- Customer reviews (assigns provided by ProductDetailLive) --%>
      <EmakolaWeb.ReviewComponents.review_section
        :if={@reviews}
        store={@store}
        product={@product}
        reviews={@reviews}
        can_review={@can_review}
        already_reviewed={@already_reviewed}
        review_form_rating={@review_form_rating}
        review_form_title={@review_form_title}
        review_form_body={@review_form_body}
        review_submitting={@review_submitting}
        avg_rating={@product.avg_rating}
        review_count={@product.review_count}
        uploads={@uploads}
      />

      <%!-- Mobile spacer for the bottom bar --%>
      <div class="h-16 sm:hidden"></div>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.chale_bottom_nav store={@store} cart_count={@cart_count} active={:shop} />
    """
  end

  # -- Components --

  attr :variant, :map, default: nil

  defp stock_line(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="text-sm font-medium text-zinc-500">Select options</span>
      <% @variant.track_inventory and @variant.stock_quantity <= 0 -> %>
        <span class="inline-block bg-zinc-950 px-2 py-1 text-xs font-bold uppercase tracking-widest text-white">
          Sold out
        </span>
      <% @variant.track_inventory and @variant.stock_quantity < 5 -> %>
        <span class="inline-block bg-store-accent px-2 py-1 text-xs font-bold uppercase tracking-widest text-white">
          Only {@variant.stock_quantity} left
        </span>
      <% true -> %>
        <span class="text-sm font-bold uppercase tracking-wide text-zinc-950">In stock</span>
    <% end %>
    """
  end

  # -- Helpers --

  defp gone?(product, vov_map, option_value_id) do
    not Shared.option_value_available?(product, vov_map, option_value_id)
  end

  defp option_label(value, true), do: "#{value} — sold out"
  defp option_label(value, false), do: value

  defp option_tile_classes(selected?, gone?) do
    base =
      "flex h-12 min-w-[48px] cursor-pointer items-center justify-center border-2 px-4 " <>
        "text-sm font-bold uppercase focus-visible:outline-none focus-visible:ring-2 " <>
        "focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors"

    cond do
      selected? -> "#{base} border-zinc-950 bg-zinc-950 text-white"
      gone? -> "#{base} border-zinc-300 bg-white text-zinc-400 line-through"
      true -> "#{base} border-zinc-950 bg-white text-zinc-950 hover:bg-zinc-100"
    end
  end
end
