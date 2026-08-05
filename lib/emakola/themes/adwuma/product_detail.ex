defmodule Emakola.Themes.Adwuma.ProductDetail do
  @moduledoc """
  Adwuma PDP.

  Only these five `phx-click` names appear here, because they are the only ones
  `ProductDetailLive` handles: `select_image`, `select_option`,
  `increment_quantity`, `decrement_quantity`, `add_to_cart`. A sixth is a
  `FunctionClauseError` and a dead page — storefront LiveViews have no
  catch-all `handle_event/3`.

  ## The fulfilment line

  `pdp_parity_test` requires delivery terms on every theme's PDP, but a
  download has no delivery. The branch is on the product's own recorded type,
  and **everything that is not explicitly digital takes the delivery path** —
  including `nil` and any type added later. That keeps the asserted branch the
  default, so a theme cannot accidentally opt out of it.

  The digital line is "In your account after payment", which is true: the grant
  is issued when `Order :confirm` runs the fulfilment worker. It is deliberately
  not "Instant download" — the grant comes from a queued Oban job, so "instant"
  is a promise the system does not strictly keep.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Adwuma.Shared
  alias Emakola.Themes.Akwaaba.Shared, as: Cards
  alias EmakolaWeb.Helpers.Currency

  @digital_types [:digital_download, :license_key, :streaming, :course]

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Adwuma)
      |> assign(:digital, digital?(assigns.product))

    ~H"""
    <div class="min-h-screen bg-[color:var(--adw-bg)] pb-16 text-[color:var(--adw-ink)] sm:pb-0">
      <Shared.theme_styles theme={@theme} />

      <Shared.adwuma_nav
        store={@store}
        categories={Map.get(assigns, :categories) || []}
        cart_count={Map.get(assigns, :cart_count) || 0}
      />

      <main class="mx-auto max-w-6xl px-4 py-12 sm:px-6 [font-family:var(--adw-body)]">
        <nav class="text-sm text-[color:var(--adw-muted)]" aria-label="Breadcrumb">
          <a href={store_path(@store.slug, "/products")} class="hover:text-[color:var(--adw-ink)]">
            Shop
          </a>
          <span aria-hidden="true">/</span>
          <span class="text-[color:var(--adw-ink)]">{@product.title}</span>
        </nav>

        <div class="mt-6 grid gap-10 lg:grid-cols-2">
          <div>
            <div class="aspect-[4/3] overflow-hidden rounded-2xl border border-[color:var(--adw-rule)] bg-white">
              <Cards.photo_or_initial
                image={Cards.current_image(@product, @current_image_index)}
                title={@product.title}
              />
            </div>

            <ul :if={length(@product.images || []) > 1} class="mt-3 flex flex-wrap gap-2">
              <li :for={{_image, idx} <- Enum.with_index(@product.images)}>
                <button
                  type="button"
                  phx-click="select_image"
                  phx-value-index={idx}
                  class={[
                    "h-16 w-16 overflow-hidden rounded-xl border bg-white",
                    if(@current_image_index == idx,
                      do: "border-[color:var(--adw-ink)]",
                      else: "border-[color:var(--adw-rule)]"
                    )
                  ]}
                >
                  <img
                    src={Cards.current_image(@product, idx)}
                    alt=""
                    class="h-full w-full object-cover"
                  />
                </button>
              </li>
            </ul>
          </div>

          <div>
            <h1 class="text-3xl font-semibold tracking-tight text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
              {@product.title}
            </h1>

            <Emakola.Themes.Shared.RealPhotoBadge.badge product={@product} />

            <p class="mt-3 text-2xl font-semibold tabular-nums text-[color:var(--adw-ink)]">
              {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
            </p>

            <p
              :if={@product.description}
              class="mt-5 text-base leading-relaxed text-[color:var(--adw-muted)]"
            >
              {@product.description}
            </p>

            <div :if={@option_types != []} class="mt-8 space-y-5">
              <div :for={option_type <- @option_types}>
                <p class="text-xs font-bold uppercase tracking-[0.18em] text-[color:var(--adw-muted)]">
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
                      "min-h-[44px] rounded-full border px-5 text-sm font-semibold",
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do: "border-[color:var(--adw-ink)] bg-[color:var(--adw-ink)] text-white",
                        else:
                          "border-[color:var(--adw-rule)] bg-white text-[color:var(--adw-ink)] hover:border-[color:var(--adw-ink)]"
                      )
                    ]}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </div>

            <%!-- Fulfilment. Physical is the default branch, and the one
                 pdp_parity_test drives. --%>
            <p
              :if={@digital}
              class="mt-8 rounded-xl border border-[color:var(--adw-rule)] bg-white px-4 py-3 text-sm text-[color:var(--adw-ink)]"
            >
              In your account after payment.
            </p>
            <p
              :if={!@digital && Emakola.Themes.Delivery.callout(assigns)}
              class="mt-8 rounded-xl border border-[color:var(--adw-rule)] bg-white px-4 py-3 text-sm text-[color:var(--adw-ink)]"
            >
              {Emakola.Themes.Delivery.callout(assigns)}
            </p>

            <%!-- Merchant-stated returns/warranty. Renders nothing when the
                 merchant stated nothing. Applies to downloads too. --%>
            {Emakola.Themes.Terms.badges(assigns)}

            <div class="mt-8 flex flex-wrap items-center gap-3">
              <div class="inline-flex items-center rounded-full border border-[color:var(--adw-rule)] bg-white">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  class="flex h-11 w-11 items-center justify-center text-lg text-[color:var(--adw-muted)]"
                >
                  <span class="sr-only">Decrease quantity</span>−
                </button>
                <span class="min-w-8 text-center text-sm font-semibold tabular-nums">
                  {@quantity}
                </span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  class="flex h-11 w-11 items-center justify-center text-lg text-[color:var(--adw-muted)]"
                >
                  <span class="sr-only">Increase quantity</span>+
                </button>
              </div>

              <button
                type="button"
                phx-click="add_to_cart"
                phx-value-product-id={@product.id}
                class="flex-1 rounded-full bg-[color:var(--adw-ink)] px-8 py-3.5 text-sm font-semibold text-white hover:bg-[color:var(--adw-lavender)]"
              >
                Add to cart
              </button>
            </div>

            <%!-- A free-sample control belongs here once DigitalFile
                 is_preview:true has a public route. It has none today, so
                 shipping the button would be a control with nowhere to go. --%>
          </div>
        </div>

        <section :if={assigns[:related_products] not in [nil, []]} class="mt-20">
          <h2 class="text-2xl font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
            More from this shop
          </h2>
          <div class="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            <%!-- show_add={false}: this page's add_to_cart ignores params and
                 adds the VIEWED product, so a related quick-add bags the
                 wrong item. --%>
            <Shared.product_card
              :for={related <- Enum.take(assigns[:related_products], 4)}
              product={related}
              store={@store}
              show_add={false}
            />
          </div>
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
      </main>

      <Shared.footer store={@store} categories={Map.get(assigns, :categories) || []} />
      <Shared.bottom_nav store={@store} cart_count={Map.get(assigns, :cart_count) || 0} />
    </div>
    """
  end

  # Everything not explicitly digital ships — including nil and any future
  # type. The asserted branch stays the default.
  defp digital?(%{product_type: type}) when type in @digital_types, do: true
  defp digital?(_product), do: false
end
