defmodule Emakola.Themes.Spotlight.ProductDetail do
  @moduledoc """
  Spotlight single-product page (centerpiece): immersive hero, benefits,
  ingredients, taste/variant selector + buy, testimonials, reviews. Lighter
  take on the LIVELY reference. Pure presentation — all events/assigns come
  from ProductDetailLive.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Spotlight.Shared

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
      |> assign(:currency, Map.get(assigns.store, :currency, "GHS"))
      |> assign(:wa_link, Shared.whatsapp_link(assigns.store, assigns.product.title))
      |> assign(:trust, get_in(assigns.theme, [:trust]) || %{})
      |> assign(:testimonials, get_in(assigns.theme, [:testimonials]) || %{})
      |> assign(:closing, get_in(assigns.theme, [:closing_cta]) || %{})
      |> assign(:ingredients, Emakola.Themes.Spotlight.ingredients())

    ~H"""
    <div class="spot-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.nav store={@store} cart_count={@cart_count} />

      <%!-- HERO --%>
      <section class="relative overflow-hidden">
        <div class="absolute -top-24 -right-24 w-96 h-96 rounded-full spot-blob opacity-60"></div>
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-20 grid lg:grid-cols-2 gap-10 items-center relative">
          <div>
            <p class="text-xs uppercase tracking-[0.25em] text-[var(--theme-accent,#7C3AED)] font-semibold">
              {get_in(@theme, [:hero, :overline]) || "The one you reach for"}
            </p>
            <h1 class="spot-display text-5xl sm:text-6xl lg:text-7xl text-[#16130F] mt-4 uppercase">
              {@product.title}
            </h1>
            <p class="text-[#6B675F] text-base mt-5 max-w-md leading-relaxed">
              {@product.description || get_in(@theme, [:hero, :tagline])}
            </p>
            <div class="flex items-center gap-4 mt-7">
              <span class="spot-heading text-2xl font-extrabold">
                {EmakolaWeb.Helpers.Currency.format_price(@price, @currency)}
              </span>
              <span
                :if={Map.get(@product, :review_count, 0) > 0}
                class="text-sm text-[#6B675F]"
              >
                <span class="text-[#16130F]">{stars(@product)}</span>
                {format_rating(@product)} ({@product.review_count})
              </span>
            </div>
            <div class="flex flex-wrap gap-3 mt-7">
              <button
                type="button"
                phx-click="add_to_cart"
                disabled={!in_stock?(@selected_variant)}
                class={"rounded-full px-7 py-3.5 text-sm font-semibold uppercase tracking-wider " <> if(in_stock?(@selected_variant), do: "spot-cta", else: "bg-[#ECE7DE] text-[#9b968c] cursor-not-allowed")}
              >
                {if in_stock?(@selected_variant), do: "Add to cart", else: "Sold out"}
              </button>
              <a
                :if={@wa_link}
                href={@wa_link}
                target="_blank"
                rel="noopener"
                class="rounded-full px-7 py-3.5 text-sm font-semibold border border-whatsapp text-[#128C3A] hover:bg-whatsapp/5"
              >
                Order on WhatsApp
              </a>
            </div>
            <p
              :if={get_in(@theme, [:hero, :badge]) not in [nil, ""]}
              class="text-[11px] uppercase tracking-wider text-[#7A7468] mt-5"
            >
              {get_in(@theme, [:hero, :badge])}
            </p>
          </div>
          <div class="relative">
            <div class="rounded-3xl overflow-hidden bg-white border border-[#ECE7DE] aspect-[4/5]">
              <.optimized_image
                :if={Shared.current_image(@product, @current_image_index)}
                src={Shared.current_image(@product, @current_image_index)}
                alt={@product.title}
                class="w-full h-full object-cover"
              />
              <div
                :if={!Shared.current_image(@product, @current_image_index)}
                class="w-full h-full flex items-center justify-center bg-[#F3EFE8]"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-24 h-24 text-[#d8d0c2]"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
                </svg>
              </div>
            </div>
            <div :if={length(@product.images) > 1} class="flex gap-2 mt-3">
              <button
                :for={{image, idx} <- Enum.with_index(@product.images)}
                type="button"
                phx-click="select_image"
                phx-value-index={idx}
                class={"w-14 h-14 rounded-xl overflow-hidden border " <> if(idx == @current_image_index, do: "border-[var(--theme-accent,#7C3AED)]", else: "border-[#ECE7DE] opacity-70")}
              >
                <img
                  src={Map.get(image, :thumbnail_url) || Map.get(image, :url)}
                  alt={"#{@product.title} #{idx + 1}"}
                  class="w-full h-full object-cover"
                />
              </button>
            </div>
          </div>
        </div>
      </section>

      <%!-- BENEFITS --%>
      <section
        id="benefits"
        phx-hook="ScrollReveal"
        class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16"
      >
        <h2 class="spot-heading text-3xl font-bold text-center mb-10">
          {Map.get(@trust, :title, "What makes it different")}
        </h2>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-6">
          <div
            :for={item <- Map.get(@trust, :items, [])}
            data-reveal
            class="rounded-2xl bg-white border border-[#ECE7DE] p-6 text-center"
          >
            <span class="material-symbols-outlined text-[var(--theme-accent,#7C3AED)] text-3xl">
              {Map.get(item, :icon, "star")}
            </span>
            <h3 class="spot-heading text-base font-semibold mt-3">{item.title}</h3>
            <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{item.description}</p>
          </div>
        </div>
      </section>

      <%!-- STATEMENT --%>
      <section class="bg-[var(--theme-accent-soft)]">
        <div class="max-w-[900px] mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
          <span class="material-symbols-outlined text-[var(--theme-accent,#7C3AED)] text-3xl">
            auto_awesome
          </span>
          <p class="spot-display text-3xl sm:text-4xl text-[#16130F] mt-4 leading-tight">
            {Map.get(@closing, :title, "One product, done properly.")}
          </p>
          <p class="text-[#6B675F] mt-4">{Map.get(@closing, :subtitle)}</p>
          <a
            href="#buy"
            class="inline-block mt-7 rounded-full spot-cta px-7 py-3.5 text-sm font-semibold uppercase tracking-wider"
          >
            {Map.get(@closing, :button_text, "Get yours")}
          </a>
        </div>
      </section>

      <%!-- INGREDIENTS --%>
      <section
        id="ingredients"
        phx-hook="ScrollReveal"
        class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16"
      >
        <h2 class="spot-heading text-3xl font-bold mb-2">{length(@ingredients)} reasons it works</h2>
        <p class="text-[#6B675F] mb-10 max-w-xl">
          Everything that goes in, and why it matters. Nothing superfluous.
        </p>
        <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-x-10 gap-y-8">
          <div :for={ing <- @ingredients} data-reveal class="border-t border-[#ECE7DE] pt-4">
            <h3 class="spot-heading text-lg font-semibold">{ing.name}</h3>
            <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{ing.description}</p>
          </div>
        </div>
      </section>

      <%!-- BUY: taste selector --%>
      <section id="buy" class="bg-white border-y border-[#ECE7DE]">
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 grid lg:grid-cols-2 gap-10 items-center">
          <div class="rounded-3xl overflow-hidden bg-[#F3EFE8] aspect-square">
            <.optimized_image
              :if={Shared.first_image(@product)}
              src={Shared.first_image(@product)}
              alt={@product.title}
              class="w-full h-full object-cover"
            />
          </div>
          <div>
            <h2 class="spot-heading text-3xl font-bold">{@product.title}</h2>
            <div :if={@option_types != []} class="space-y-5 mt-6">
              <div :for={option_type <- @option_types}>
                <div class="text-xs uppercase tracking-wider text-[#6B675F] mb-2">
                  {option_type.name}:
                  <span class="text-[#16130F] font-semibold">
                    {selected_label(option_type, @selected_options)}
                  </span>
                </div>
                <div class="flex flex-wrap gap-2">
                  <button
                    :for={ov <- option_type.option_values || []}
                    type="button"
                    phx-click="select_option"
                    phx-value-option_type_id={option_type.id}
                    phx-value-value={ov.id}
                    class={"min-h-[44px] px-5 py-2.5 rounded-full text-sm border transition-colors " <> if(Map.get(@selected_options, option_type.id) == ov.id, do: "border-[var(--theme-accent,#7C3AED)] bg-[var(--theme-accent,#7C3AED)] text-white font-medium", else: "border-[#ECE7DE] bg-white hover:border-[var(--theme-accent,#7C3AED)]")}
                  >
                    {ov.value}
                  </button>
                </div>
              </div>
            </div>
            <div class="flex items-center gap-4 mt-7">
              <span class="spot-heading text-2xl font-extrabold">
                {EmakolaWeb.Helpers.Currency.format_price(@price, @currency)}
              </span>
              <div class="flex items-center border border-[#ECE7DE] rounded-full">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  class="w-10 h-10 flex items-center justify-center"
                  aria-label="Decrease quantity"
                >
                  −
                </button>
                <span class="w-10 text-center text-sm font-medium">{@quantity}</span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  class="w-10 h-10 flex items-center justify-center"
                  aria-label="Increase quantity"
                >
                  +
                </button>
              </div>
              <span class="text-xs" style={"color: #{stock_color(@selected_variant)}"}>
                {stock_label(@selected_variant)}
              </span>
            </div>
            <button
              type="button"
              phx-click="add_to_cart"
              disabled={!in_stock?(@selected_variant)}
              class={"w-full sm:w-auto mt-6 rounded-full px-10 py-4 text-sm font-semibold uppercase tracking-wider " <> if(in_stock?(@selected_variant), do: "spot-cta", else: "bg-[#ECE7DE] text-[#9b968c] cursor-not-allowed")}
            >
              {if in_stock?(@selected_variant), do: "Add to cart", else: "Out of stock"}
            </button>
            <a
              :if={@wa_link}
              href={@wa_link}
              target="_blank"
              rel="noopener"
              class="block sm:inline-block mt-3 sm:ml-3 text-center rounded-full px-8 py-4 text-sm font-semibold border border-whatsapp text-[#128C3A] hover:bg-whatsapp/5"
            >
              Order on WhatsApp
            </a>
            <a
              href={store_path(@store.slug, "/cart")}
              class="block mt-4 text-sm text-[var(--theme-accent,#7C3AED)] hover:underline"
            >
              View cart ({@cart_count}) →
            </a>
          </div>
        </div>
      </section>

      <%!-- TESTIMONIALS --%>
      <section
        phx-hook="ScrollReveal"
        id="testimonials"
        class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16"
      >
        <h2 class="spot-heading text-3xl font-bold text-center mb-10">
          {Map.get(@testimonials, :title, "Loved by everyday people")}
        </h2>
        <div class="grid md:grid-cols-3 gap-6">
          <figure
            :for={t <- Map.get(@testimonials, :items, [])}
            data-reveal
            class="rounded-2xl bg-white border border-[#ECE7DE] p-6"
          >
            <div class="text-[var(--theme-accent,#7C3AED)]">★★★★★</div>
            <blockquote class="text-sm text-[#16130F] mt-3 leading-relaxed">"{t.quote}"</blockquote>
            <figcaption class="text-xs text-[#6B675F] mt-4 font-semibold">
              {t.name}<span :if={Map.get(t, :location)} class="font-normal"> · {t.location}</span>
            </figcaption>
          </figure>
        </div>
      </section>

      <%!-- REVIEWS (only when LiveView provides review assigns) --%>
      <section
        :if={assigns[:reviews] != nil}
        id="reviews"
        class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 border-t border-[#ECE7DE]"
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

      <Shared.footer store={@store} />
    </div>
    """
  end

  # ── Helpers ──
  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0

  defp in_stock?(%{track_inventory: _} = variant), do: Emakola.Catalog.Variant.in_stock?(variant)
  defp in_stock?(_), do: true

  defp stock_label(%{track_inventory: false}), do: "In stock"
  defp stock_label(%{stock_quantity: q}) when is_integer(q) and q <= 0, do: "Out of stock"
  defp stock_label(%{stock_quantity: q}) when is_integer(q) and q <= 5, do: "Only #{q} left"
  defp stock_label(_), do: "In stock"

  defp stock_color(%{track_inventory: false}), do: "#16A34A"
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
      %Decimal{} = r -> Decimal.to_string(r)
      r when is_float(r) -> :erlang.float_to_binary(r, decimals: 1)
      r when is_integer(r) -> "#{r}"
      _ -> nil
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
