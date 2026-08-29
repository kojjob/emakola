defmodule Emakola.Themes.Heirloom.ProductDetail do
  @moduledoc """
  Heirloom product detail — the full capability set.

  An audit of all twenty themes found none that wired everything
  `EmakolaWeb.Storefront.ProductDetailLive` supports, so this one is built
  against the LiveView rather than against a peer theme. It renders:

  gallery (`select_image`, `prev_image`, `next_image`), quantity
  (`increment_quantity`, `decrement_quantity`), variant selection
  (`select_option`), `add_to_cart`, real sale and sold-out state, the
  delivery callout built from the store's own zones, related products,
  reviews, and the share strip.

  Two things are deliberately absent because `ProductDetailLive.render/1`
  emits them itself, wrapped around this output: the group-buy campaigns and
  the "Fulfilled by verified partner" disclosure. Rendering our own would
  duplicate them.

  ## The variant picker

  Option buttons send `phx-value-option_type_id` and
  `phx-value-option_value_id`. They must never use the generic `value` param
  name: the browser overwrites that attribute with the element's own `.value`
  property, which is `""` on a `<button>`, and it silently broke variant
  selection on every theme at once. `EmakolaWeb.PhxValueCollisionTest` guards
  it with a plain text scan over `lib/`, which is why this paragraph describes
  the offending attribute rather than spelling it.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1, share_strip: 1]

  alias Emakola.Themes.Delivery
  alias Emakola.Themes.Heirloom.ProductList
  alias Emakola.Themes.Heirloom.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Heirloom)
      |> assign(:images, Map.get(assigns.product, :images) || [])
      |> assign(:related, assigns[:related_products] || [])

    ~H"""
    <div class="min-h-screen bg-[color:var(--hl-bg)] [font-family:var(--hl-font)]">
      <Shared.theme_styles theme={@theme} />
      <Shared.heirloom_nav store={@store} cart_count={assigns[:cart_count] || 0} on_dark={false} />

      <main class="mx-auto max-w-[1360px] px-5 pb-24 pt-8 sm:px-8">
        <nav
          aria-label="Breadcrumb"
          class="text-[11px] uppercase tracking-[0.16em] text-[color:var(--hl-muted)]"
        >
          <a href={store_path(@store.slug, "/products")} class="hover:text-[color:var(--hl-ink)]">
            Collection
          </a>
          <span aria-hidden="true" class="mx-2">/</span>
          <span class="text-[color:var(--hl-ink)]">{@product.title}</span>
        </nav>

        <div class="mt-8 grid gap-12 lg:grid-cols-2 lg:gap-16">
          <div>
            <div class="relative overflow-hidden rounded-[28px] bg-[color:var(--hl-tile)]">
              <div class="aspect-[4/5]">
                <.optimized_image
                  src={current_image(@images, @current_image_index)}
                  alt={@product.title}
                  width={1000}
                  height={1000}
                  class="h-full w-full object-cover"
                />
              </div>

              <button
                :if={length(@images) > 1}
                type="button"
                phx-click="prev_image"
                aria-label="Previous image"
                class="absolute left-4 top-1/2 flex h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full bg-white/90 text-[color:var(--hl-ink)] shadow hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)]"
              >
                &larr;
              </button>
              <button
                :if={length(@images) > 1}
                type="button"
                phx-click="next_image"
                aria-label="Next image"
                class="absolute right-4 top-1/2 flex h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full bg-white/90 text-[color:var(--hl-ink)] shadow hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)]"
              >
                &rarr;
              </button>
            </div>

            <ul :if={length(@images) > 1} class="mt-4 grid grid-cols-5 gap-3">
              <li :for={{_image, idx} <- Enum.with_index(@images)}>
                <button
                  type="button"
                  phx-click="select_image"
                  phx-value-index={idx}
                  aria-label={"Show image #{idx + 1}"}
                  aria-current={@current_image_index == idx && "true"}
                  class={[
                    "aspect-square w-full overflow-hidden rounded-2xl bg-[color:var(--hl-tile)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)] focus-visible:ring-offset-2",
                    @current_image_index == idx && "ring-2 ring-[color:var(--hl-ink)]"
                  ]}
                >
                  <.optimized_image
                    src={current_image(@images, idx)}
                    alt=""
                    width={200}
                    height={200}
                    class="h-full w-full object-cover"
                  />
                </button>
              </li>
            </ul>
          </div>

          <div>
            <h1 class="text-4xl font-light leading-tight tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)] sm:text-5xl">
              {@product.title}
            </h1>

            <Emakola.Themes.Shared.RealPhotoBadge.badge product={@product} />

            <p class="mt-5 flex flex-wrap items-baseline gap-3">
              <span
                :if={@selected_variant}
                class="text-3xl font-semibold tabular-nums text-[color:var(--hl-ink)]"
              >
                {Currency.format_price(@selected_variant.price, @store.currency)}
              </span>
              <s :if={on_sale?(@selected_variant)} class="text-lg text-[color:var(--hl-muted)]">
                <span class="sr-only">was</span>
                {Currency.format_price(@selected_variant.compare_at_price, @store.currency)}
              </s>
            </p>

            <p
              :if={@product.description}
              class="mt-6 max-w-prose text-sm leading-relaxed text-[color:var(--hl-muted)]"
            >
              {@product.description}
            </p>

            <div :if={@option_types != []} class="mt-9 space-y-6">
              <div :for={option_type <- @option_types}>
                <p class="text-[11px] font-semibold uppercase tracking-[0.16em] text-[color:var(--hl-muted)]">
                  {option_type.name}
                </p>
                <div class="mt-3 flex flex-wrap gap-2">
                  <button
                    :for={option_value <- option_type.option_values || []}
                    type="button"
                    phx-click="select_option"
                    phx-value-option_type_id={option_type.id}
                    phx-value-option_value_id={option_value.id}
                    aria-pressed={
                      to_string(Map.get(@selected_options, option_type.id) == option_value.id)
                    }
                    class={[
                      "min-h-[44px] rounded-full border px-5 text-sm font-medium motion-safe:transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)]",
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do: "border-[color:var(--hl-ink)] bg-[color:var(--hl-ink)] text-white",
                        else:
                          "border-[color:var(--hl-border)] bg-white text-[color:var(--hl-ink)] hover:border-[color:var(--hl-ink)]"
                      )
                    ]}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </div>

            <div class="mt-9 flex flex-wrap items-center gap-4">
              <div class="flex items-center gap-1 rounded-full border border-[color:var(--hl-border)] bg-white p-1">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  disabled={@quantity <= 1}
                  aria-label="Decrease quantity"
                  class="flex h-11 w-11 items-center justify-center rounded-full text-lg text-[color:var(--hl-ink)] disabled:opacity-30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)]"
                >
                  &minus;
                </button>
                <span
                  class="min-w-[2rem] text-center text-sm font-semibold tabular-nums"
                  aria-live="polite"
                >
                  {@quantity}
                </span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  disabled={@quantity >= 10}
                  aria-label="Increase quantity"
                  class="flex h-11 w-11 items-center justify-center rounded-full text-lg text-[color:var(--hl-ink)] disabled:opacity-30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)]"
                >
                  +
                </button>
              </div>

              <button
                :if={purchasable?(@selected_variant)}
                type="button"
                phx-click="add_to_cart"
                class="min-h-[52px] flex-1 rounded-full bg-[color:var(--hl-ink)] px-10 text-[11px] font-semibold uppercase tracking-[0.16em] text-white motion-safe:transition-transform hover:scale-[1.01] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)] focus-visible:ring-offset-2"
              >
                Add to bag
              </button>

              <p
                :if={!purchasable?(@selected_variant)}
                class="min-h-[52px] flex-1 rounded-full bg-[color:var(--hl-tile)] px-10 text-center text-[11px] font-semibold uppercase leading-[52px] tracking-[0.16em] text-[color:var(--hl-muted)]"
              >
                Sold out
              </p>
            </div>

            <%!-- Delivery.callout/1 returns a string built from the store's OWN
                 delivery zones, or nil when it has configured none. Never a
                 theme default — a hardcoded "free delivery in Accra" would be
                 a promise the merchant never made. --%>
            <p
              :if={Delivery.callout(assigns)}
              class="mt-8 flex items-center gap-2 text-sm font-medium text-[color:var(--hl-ink)]"
            >
              <span
                aria-hidden="true"
                class="inline-block h-1.5 w-1.5 rounded-full bg-[color:var(--hl-accent)]"
              />
              {Delivery.callout(assigns)}
            </p>

            <.share_strip
              url={
                assigns[:canonical_url] ||
                  store_path(@store.slug, "/products/#{@product.slug}")
              }
              title={@product.title}
              on_share="share-product"
              share_value={@product.id}
              class="mt-8"
            />
          </div>
        </div>

        <%!-- Guarded and defaulted: this module is also rendered by
             component tests that build assigns without the review keys,
             where reading @reviews would raise. --%>
        <EmakolaWeb.ReviewComponents.review_section
          :if={assigns[:reviews] != nil}
          store={@store}
          product={@product}
          reviews={assigns[:reviews] || []}
          can_review={assigns[:can_review] || false}
          already_reviewed={assigns[:already_reviewed] || false}
          review_form={assigns[:review_form]}
          review_form_rating={assigns[:review_form_rating] || 0}
          review_form_title={assigns[:review_form_title] || ""}
          review_form_body={assigns[:review_form_body] || ""}
          review_submitting={assigns[:review_submitting] || false}
          avg_rating={Map.get(@product, :avg_rating)}
          review_count={Map.get(@product, :review_count, 0)}
          uploads={assigns[:uploads]}
        />

        <section :if={@related != []} class="mt-20">
          <h2 class="text-2xl font-light tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)]">
            You may also like
          </h2>
          <ul class="mt-8 grid grid-cols-2 gap-x-4 gap-y-10 lg:grid-cols-4 lg:gap-x-6">
            <li :for={item <- Enum.take(@related, 4)}>
              <ProductList.tile product={item} store={@store} />
            </li>
          </ul>
        </section>
      </main>
    </div>

    <Shared.footer store={@store} categories={assigns[:categories] || []} />
    """
  end

  defp current_image([], _index), do: nil

  defp current_image(images, index) do
    sorted = Enum.sort_by(images, & &1.position)
    image = Enum.at(sorted, index || 0) || List.first(sorted)
    image && (image.url || image.thumbnail_url)
  end

  defp on_sale?(nil), do: false

  defp on_sale?(variant) do
    not is_nil(variant.compare_at_price) and variant.compare_at_price > variant.price
  end

  defp purchasable?(nil), do: false
  defp purchasable?(variant), do: Emakola.Catalog.Variant.in_stock?(variant)
end
