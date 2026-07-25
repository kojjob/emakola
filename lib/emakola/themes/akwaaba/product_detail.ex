defmodule Emakola.Themes.Akwaaba.ProductDetail do
  @moduledoc """
  Akwaaba product detail — the photograph, then the decision.

  Every `phx-click` here names an event the storefront LiveView actually
  handles: `select_image`, `select_option`, `increment_quantity`,
  `decrement_quantity`, `add_to_cart`. Inventing a sixth would crash the page.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Akwaaba.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Akwaaba)

    ~H"""
    <div class="min-h-screen bg-white [font-family:var(--akwaaba-body)]">
      <Shared.theme_styles theme={@theme} />
      <Shared.akwaaba_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <main class="mx-auto max-w-[1320px] px-5 pb-24 pt-8 sm:px-10">
        <nav
          aria-label="Breadcrumb"
          class="text-xs font-medium uppercase tracking-[0.2em] text-zinc-400"
        >
          <a
            href={store_path(@store.slug, "/products")}
            class="hover:text-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)]"
          >
            Shop
          </a>
          <span aria-hidden="true" class="mx-2">/</span>
          <span class="text-[color:var(--akwaaba-ink)]">{@product.title}</span>
        </nav>

        <div class="mt-6 grid gap-10 lg:grid-cols-2 lg:gap-14">
          <div>
            <div class="group relative aspect-[4/5] overflow-hidden rounded-[2rem] bg-[#F6F4F1]">
              <Shared.photo_or_initial
                image={Shared.first_image(@product)}
                title={@product.title}
                sizes={[900, 1125]}
              />
            </div>

            <ul :if={length(@product.images) > 1} class="mt-3 grid grid-cols-4 gap-3">
              <li :for={{_image, idx} <- Enum.with_index(@product.images)}>
                <button
                  type="button"
                  phx-click="select_image"
                  phx-value-index={idx}
                  aria-label={"Show image #{idx + 1}"}
                  aria-current={@current_image_index == idx && "true"}
                  class={[
                    "aspect-square w-full overflow-hidden rounded-2xl bg-[#F6F4F1] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2",
                    @current_image_index == idx && "ring-2 ring-[color:var(--akwaaba-ink)]"
                  ]}
                >
                  <.optimized_image
                    src={Shared.current_image(@product, idx)}
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
            <h1 class="text-4xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)] sm:text-5xl">
              {@product.title}
            </h1>

            <p class="mt-4 flex flex-wrap items-baseline gap-3">
              <span
                :if={@selected_variant}
                class="text-3xl font-semibold tabular-nums text-[color:var(--akwaaba-ink)]"
              >
                {Currency.format_price(@selected_variant.price, @store.currency)}
              </span>
              <s
                :if={
                  @selected_variant && @selected_variant.compare_at_price &&
                    @selected_variant.compare_at_price > @selected_variant.price
                }
                class="text-lg text-zinc-400"
              >
                <span class="sr-only">was</span>
                {Currency.format_price(@selected_variant.compare_at_price, @store.currency)}
              </s>
            </p>

            <p :if={@product.description} class="mt-5 max-w-prose leading-relaxed text-zinc-600">
              {@product.description}
            </p>

            <div :if={@option_types != []} class="mt-8 space-y-5">
              <div :for={option_type <- @option_types}>
                <p class="text-xs font-bold uppercase tracking-[0.18em] text-zinc-500">
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
                      "min-h-[44px] rounded-full border px-5 text-sm font-semibold motion-safe:transition-colors",
                      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)]",
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do:
                          "border-[color:var(--akwaaba-ink)] bg-[color:var(--akwaaba-ink)] text-white",
                        else:
                          "border-zinc-200 bg-white text-[color:var(--akwaaba-ink)] hover:border-[color:var(--akwaaba-sun)]"
                      )
                    ]}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </div>

            <%!-- Built from the store's own delivery zones; renders nothing when it
                 has configured none. Never a theme default — a hardcoded "free
                 delivery in Accra" would be a promise the merchant never made. --%>
            <p
              :if={Emakola.Themes.Delivery.callout(assigns)}
              class="mb-3 flex items-center gap-2 text-sm font-medium"
            >
              <span
                aria-hidden="true"
                class="inline-block h-1.5 w-1.5 rounded-full bg-current opacity-60"
              />
              {Emakola.Themes.Delivery.callout(assigns)}
            </p>
            <div class="mt-8 flex flex-wrap items-center gap-4">
              <div class="flex items-center gap-1 rounded-full border border-zinc-200 p-1">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  disabled={@quantity <= 1}
                  aria-label="Decrease quantity"
                  class="flex h-10 w-10 items-center justify-center rounded-full text-lg font-bold text-[color:var(--akwaaba-ink)] disabled:opacity-30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)]"
                >
                  &minus;
                </button>
                <span
                  class="min-w-[2rem] text-center text-sm font-bold tabular-nums"
                  aria-live="polite"
                >
                  {@quantity}
                </span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  disabled={@quantity >= 10}
                  aria-label="Increase quantity"
                  class="flex h-10 w-10 items-center justify-center rounded-full text-lg font-bold text-[color:var(--akwaaba-ink)] disabled:opacity-30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)]"
                >
                  +
                </button>
              </div>

              <button
                :if={purchasable?(@selected_variant)}
                type="button"
                phx-click="add_to_cart"
                phx-value-product-id={@product.id}
                class="min-h-[52px] flex-1 rounded-full bg-[color:var(--akwaaba-ink)] px-8 text-sm font-bold text-white hover:bg-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2 motion-safe:transition-colors"
              >
                Add to cart
              </button>

              <p
                :if={!purchasable?(@selected_variant)}
                class="min-h-[52px] flex-1 rounded-full bg-zinc-100 px-8 text-center text-sm font-bold leading-[52px] text-zinc-400"
              >
                Sold out
              </p>
            </div>
          </div>
        </div>

        <%!-- `show_add={false}` is not cosmetic. The detail page's `add_to_cart`
             takes no params and adds `@selected_variant` — the product being
             viewed — so an add button on a related card would put the WRONG
             product in the bag. Related cards link; they do not buy. --%>
        <section :if={assigns[:related_products] not in [nil, []]} class="mt-20">
          <h2 class="text-2xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
            More from {@store.name}
          </h2>
          <ul class="mt-6 grid grid-cols-2 gap-x-4 gap-y-8 lg:grid-cols-4 lg:gap-x-6">
            <li :for={related <- Enum.take(assigns[:related_products], 4)}>
              <Shared.product_card product={related} store={@store} show_add={false} />
            </li>
          </ul>
        </section>

        <EmakolaWeb.ReviewComponents.review_section
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

        <div class="h-16 sm:hidden"></div>
      </main>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.bottom_nav store={@store} cart_count={@cart_count} active={:shop} />
    """
  end

  defp purchasable?(nil), do: false
  defp purchasable?(variant), do: Emakola.Catalog.Variant.in_stock?(variant)
end
