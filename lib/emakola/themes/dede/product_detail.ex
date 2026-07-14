defmodule Emakola.Themes.Dede.ProductDetail do
  @moduledoc """
  Dede theme — the dish page, ordered with a thumb.

  Mobile-first single column: name, unmissable availability, price, then
  the order controls in a bar that sticks to the bottom of a phone screen —
  add to order and WhatsApp are always one thumb-reach away. Photo-optional:
  with no image the page opens on a slim board band carrying the dish
  initial, not a photo-shaped hole. Related dishes render as board rows.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Dede.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    orderable? =
      assigns.selected_variant != nil and
        Emakola.Catalog.Variant.in_stock?(assigns.selected_variant)

    assigns =
      assigns
      |> assign(:orderable, orderable?)
      |> assign(:image, Shared.current_image(assigns.product, assigns.current_image_index))
      |> assign(:whatsapp, Shared.whatsapp_link(assigns.store, assigns.product.title))

    ~H"""
    <div class="min-h-screen bg-[#FAF5EA]">
      <Shared.dede_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <div class="mx-auto max-w-[880px] px-4 pt-5 sm:px-6 sm:pt-8 lg:px-8">
        <div class="sm:grid sm:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] sm:items-start sm:gap-8">
          <div>
            <div :if={@image} class="overflow-hidden rounded-2xl border-2 border-[#26211A]/10">
              <.optimized_image
                src={@image}
                alt={@product.title}
                priority={:high}
                width={640}
                height={480}
                class="aspect-[4/3] w-full object-cover"
              />
            </div>
            <div
              :if={!@image}
              class="flex h-28 items-center justify-center rounded-2xl bg-[#1B2E23] ring-1 ring-inset ring-white/10 sm:h-40"
              aria-hidden="true"
            >
              <span class="select-none text-6xl uppercase text-[#F3EDDF]/80 [font-family:var(--dt-heading-font,'Anton',sans-serif)]">
                {String.first(@product.title)}
              </span>
            </div>
            <div
              :if={length(@product.images) > 1}
              class="mt-3 flex items-center justify-center gap-2"
            >
              <button
                :for={{_image, index} <- Enum.with_index(@product.images)}
                type="button"
                phx-click="select_image"
                phx-value-index={index}
                aria-label={"Image #{index + 1}"}
                aria-current={to_string(index == @current_image_index)}
                class={[
                  "h-2.5 cursor-pointer rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-all",
                  if(index == @current_image_index,
                    do: "w-7 bg-[#26211A]",
                    else: "w-2.5 bg-[#26211A]/25 hover:bg-[#26211A]/50"
                  )
                ]}
              >
              </button>
            </div>
          </div>

          <div class="mt-5 sm:mt-0">
            <h1 class="text-3xl uppercase leading-[0.95] tracking-wide text-[#26211A] [font-family:var(--dt-heading-font,'Anton',sans-serif)] sm:text-4xl">
              {@product.title}
            </h1>

            <p
              :if={@orderable}
              class="mt-2.5 inline-flex items-center gap-1.5 text-sm font-bold text-[#166534]"
            >
              <span class="h-2 w-2 rounded-full bg-[#166534] motion-safe:animate-pulse"></span>
              Available now
            </p>
            <p
              :if={@selected_variant && !@orderable}
              class="mt-3 inline-block -rotate-2 rounded border-2 border-[#26211A] px-2.5 py-1 text-xs font-bold uppercase tracking-[0.15em] text-[#26211A]"
            >
              Sold out today
            </p>

            <p class="mt-3 text-3xl font-bold tabular-nums text-[#26211A]">
              <%= if @selected_variant do %>
                {Currency.format_price(@selected_variant.price, @store.currency)}
              <% else %>
                {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
              <% end %>
            </p>

            <p :if={@product.description} class="mt-4 text-[0.9375rem] leading-relaxed text-[#6B6355]">
              {@product.description}
            </p>

            <div :if={@option_types != []} class="mt-6 space-y-5" aria-label="Dish options">
              <div :for={option_type <- @option_types}>
                <p class="mb-2.5 text-sm font-bold text-[#26211A]">{option_type.name}</p>
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
                    phx-value-option_value_id={option_value.id}
                    role="radio"
                    aria-checked={
                      to_string(Map.get(@selected_options, option_type.id) == option_value.id)
                    }
                    class={[
                      "inline-flex min-h-11 cursor-pointer items-center rounded-full border-2 px-5 text-sm font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-colors",
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do: "border-[#1B2E23] bg-[#1B2E23] text-[#F3EDDF]",
                        else: "border-[#26211A]/20 bg-white text-[#26211A] hover:border-[#26211A]"
                      )
                    ]}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </div>

            <div class="mt-6 flex items-center gap-3">
              <span class="text-sm font-bold text-[#26211A]">How many?</span>
              <div class="flex items-center overflow-hidden rounded-full border-2 border-[#26211A]/20 bg-white">
                <button
                  type="button"
                  phx-click="decrement_quantity"
                  disabled={@quantity <= 1}
                  aria-label="Fewer"
                  class="flex h-11 w-11 cursor-pointer items-center justify-center text-[#26211A] hover:bg-[#FAF5EA] disabled:cursor-not-allowed disabled:text-[#26211A]/30 motion-safe:transition-colors"
                >
                  <svg
                    class="h-4 w-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    stroke-linecap="round"
                    viewBox="0 0 16 16"
                    aria-hidden="true"
                  >
                    <path d="M4 8h8" />
                  </svg>
                </button>
                <span class="flex h-11 w-10 select-none items-center justify-center text-base font-bold tabular-nums text-[#26211A]">
                  {@quantity}
                </span>
                <button
                  type="button"
                  phx-click="increment_quantity"
                  disabled={@quantity >= 10}
                  aria-label="More"
                  class="flex h-11 w-11 cursor-pointer items-center justify-center text-[#26211A] hover:bg-[#FAF5EA] disabled:cursor-not-allowed disabled:text-[#26211A]/30 motion-safe:transition-colors"
                >
                  <svg
                    class="h-4 w-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    stroke-linecap="round"
                    viewBox="0 0 16 16"
                    aria-hidden="true"
                  >
                    <path d="M8 4v8M4 8h8" />
                  </svg>
                </button>
              </div>
            </div>

            <%!-- Order bar: sticks to the bottom of a phone screen so the
            order action stays under the thumb; sits inline on desktop. --%>
            <div class="sticky bottom-0 z-30 -mx-4 mt-6 space-y-2 border-t-2 border-[#26211A]/10 bg-[#FAF5EA] px-4 py-3 sm:static sm:z-auto sm:mx-0 sm:border-0 sm:bg-transparent sm:p-0">
              <button
                :if={@orderable}
                type="button"
                phx-click="add_to_cart"
                class="flex min-h-[52px] w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-store-accent text-base font-bold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
              >
                Add to order
                <span class="tabular-nums opacity-90">
                  &middot; {Currency.format_price(
                    @selected_variant.price * @quantity,
                    @store.currency
                  )}
                </span>
              </button>
              <button
                :if={!@orderable}
                type="button"
                disabled
                aria-disabled="true"
                class="flex min-h-[52px] w-full cursor-not-allowed items-center justify-center rounded-full bg-[#26211A]/10 text-base font-bold leading-none text-[#26211A]/50"
              >
                {if @selected_variant, do: "Sold out today", else: "Choose an option"}
              </button>
              <a
                :if={@whatsapp}
                href={@whatsapp}
                target="_blank"
                rel="noopener noreferrer"
                class="flex min-h-12 w-full items-center justify-center gap-2 rounded-full border-2 border-whatsapp bg-white text-[0.9375rem] font-bold text-whatsapp hover:bg-whatsapp/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-colors"
              >
                <svg class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d={Shared.whatsapp_glyph()} />
                </svg>
                Order on WhatsApp
              </a>
            </div>

            <p class="mt-4 text-xs text-[#6B6355]">
              Delivery &amp; pickup —
              <a
                href={store_path(@store.slug, "/policies#shipping")}
                class="rounded underline decoration-[#26211A]/30 underline-offset-2 hover:text-[#26211A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A]"
              >
                see this shop's policies
              </a>
            </p>
          </div>
        </div>

        <section
          :if={@related_products != []}
          class="mt-8 sm:mt-12"
          aria-labelledby="dede-related-heading"
        >
          <div class="rounded-2xl bg-[#1B2E23] px-5 py-5 ring-1 ring-inset ring-white/10 sm:px-8 sm:py-6">
            <h2
              id="dede-related-heading"
              class="border-b-2 border-[#F3EDDF]/15 pb-3 text-xl uppercase tracking-wide text-[#F3EDDF] [font-family:var(--dt-heading-font,'Anton',sans-serif)]"
            >
              Also on the menu
            </h2>
            <ul role="list" class="divide-y divide-white/10">
              <Shared.menu_row
                :for={related <- Enum.take(@related_products, 4)}
                product={related}
                store={@store}
              />
            </ul>
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
      </div>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end
end
