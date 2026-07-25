defmodule Emakola.Themes.Sika.ProductDetail do
  @moduledoc """
  Sika theme — the piece page.

  One piece, given the whole page: vitrine-framed square image (velvet
  tray first) with quiet thumbnails, the title in the display face over
  the caught-light rule, and the price stated plainly in tabular
  numerals — no strikethroughs, no savings badges, no stock countdowns.

  Detail is the substance: the description under "The piece", the
  reference (SKU) as a hallmark stamp, options as square stamps, and a
  WhatsApp enquiry — how a considered purchase actually starts.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Sika.Shared
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    assigns = assign(assigns, :purchasable, purchasable?(assigns.selected_variant))

    ~H"""
    <div class="min-h-screen bg-[#FAF9F7] text-[#211D16] [font-family:var(--dt-body-font,Work_Sans,system-ui,sans-serif)]">
      <Shared.sika_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <nav
        class="mx-auto hidden max-w-[1200px] px-4 py-5 sm:px-6 lg:block lg:px-8"
        aria-label="Breadcrumb"
      >
        <ol class="flex items-center gap-3 text-[0.6875rem] font-medium uppercase tracking-[0.18em] text-[#6E675C]">
          <li>
            <a
              href={store_path(@store.slug, "/")}
              class="hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] motion-safe:transition-colors"
            >
              {@store.name}
            </a>
          </li>
          <li aria-hidden="true">&mdash;</li>
          <li>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] motion-safe:transition-colors"
            >
              Collection
            </a>
          </li>
          <li aria-hidden="true">&mdash;</li>
          <li class="max-w-[240px] truncate text-[#211D16]">{@product.title}</li>
        </ol>
      </nav>

      <div class="mx-auto max-w-[1200px] px-4 pb-24 pt-6 sm:px-6 lg:px-8 lg:pt-2">
        <div class="lg:grid lg:grid-cols-2 lg:gap-14">
          <%!-- Image column --%>
          <div class="lg:sticky lg:top-24 lg:self-start">
            <div class="border border-[#E8E3D9] bg-white p-2 sm:p-3">
              <div class="relative aspect-square overflow-hidden">
                <Shared.tray name={@product.title} />
                <.optimized_image
                  :if={Shared.current_image(@product, @current_image_index)}
                  src={Shared.current_image(@product, @current_image_index)}
                  alt={"#{@product.title} — image #{@current_image_index + 1}"}
                  priority={:high}
                  width={720}
                  height={720}
                  class="absolute inset-0 h-full w-full object-cover"
                />
              </div>
            </div>
            <div :if={length(@product.images) > 1} class="mt-3 grid grid-cols-5 gap-2">
              <button
                :for={{_image, idx} <- Enum.with_index(@product.images)}
                phx-click="select_image"
                phx-value-index={idx}
                aria-label={"View image #{idx + 1}"}
                class={[
                  "aspect-square cursor-pointer overflow-hidden border bg-white p-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16]",
                  if(idx == @current_image_index,
                    do: "border-[#211D16]",
                    else: "border-[#E8E3D9] opacity-70 hover:opacity-100"
                  )
                ]}
              >
                <.optimized_image
                  src={Shared.current_image(@product, idx)}
                  alt={"#{@product.title} thumbnail #{idx + 1}"}
                  priority={:low}
                  width={120}
                  height={120}
                  class="h-full w-full object-cover"
                />
              </button>
            </div>
          </div>

          <%!-- Detail column --%>
          <div class="mt-8 lg:mt-0">
            <p class="text-[0.6875rem] font-semibold uppercase tracking-[0.25em] text-[#6E675C]">
              {@store.name}
            </p>
            <h1 class="mt-2 text-3xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)] sm:text-4xl">
              {@product.title}
            </h1>
            <Shared.caught_light class="mt-5 w-16" />

            <p class="mt-5 text-2xl tabular-nums text-[#211D16]">
              <%= if @selected_variant do %>
                {Currency.format_price(@selected_variant.price, @store.currency)}
              <% else %>
                {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
              <% end %>
            </p>

            <div class="mt-4 flex flex-wrap gap-2">
              <Shared.hallmark :if={@selected_variant && @selected_variant.sku}>
                Ref {@selected_variant.sku}
              </Shared.hallmark>
              <Shared.hallmark :if={@selected_variant && !@purchasable}>
                Sold out
              </Shared.hallmark>
            </div>

            <div :if={@product.description} class="mt-7">
              <p class="text-[0.6875rem] font-semibold uppercase tracking-[0.25em] text-[#6E675C]">
                The piece
              </p>
              <p class="mt-2 whitespace-pre-line text-sm leading-relaxed text-[#4A4437] sm:text-[0.9375rem]">
                {@product.description}
              </p>
            </div>

            <div :for={option_type <- @option_types} class="mt-7">
              <p
                id={"sika-option-#{option_type.id}"}
                class="text-[0.6875rem] font-semibold uppercase tracking-[0.25em] text-[#6E675C]"
              >
                {option_type.name}
              </p>
              <div
                class="mt-3 flex flex-wrap gap-2"
                role="radiogroup"
                aria-labelledby={"sika-option-#{option_type.id}"}
              >
                <button
                  :for={option_value <- option_type.option_values}
                  phx-click="select_option"
                  phx-value-option_type_id={option_type.id}
                  phx-value-option_value_id={option_value.id}
                  role="radio"
                  aria-checked={Map.get(@selected_options, option_type.id) == option_value.id}
                  class={[
                    "min-h-[44px] min-w-[52px] cursor-pointer border px-5 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-colors",
                    if(Map.get(@selected_options, option_type.id) == option_value.id,
                      do: "border-[#1F332C] bg-[#1F332C] text-white",
                      else: "border-[#E8E3D9] bg-white text-[#211D16] hover:border-[#211D16]"
                    )
                  ]}
                >
                  {option_value.value}
                </button>
              </div>
            </div>

            <div class="mt-7 flex items-center gap-4">
              <span class="text-[0.6875rem] font-semibold uppercase tracking-[0.25em] text-[#6E675C]">
                Quantity
              </span>
              <div class="flex items-center border border-[#E8E3D9] bg-white">
                <button
                  phx-click="decrement_quantity"
                  disabled={@quantity <= 1}
                  aria-label="Decrease quantity"
                  class="flex h-11 w-11 cursor-pointer items-center justify-center text-[#211D16] hover:bg-[#FAF9F7] disabled:cursor-not-allowed disabled:text-[#C9C2B2] motion-safe:transition-colors"
                >
                  <svg
                    class="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="2"
                    aria-hidden="true"
                  >
                    <path stroke-linecap="round" d="M5 12h14" />
                  </svg>
                </button>
                <span class="flex h-11 w-11 select-none items-center justify-center border-x border-[#E8E3D9] text-sm font-medium tabular-nums">
                  {@quantity}
                </span>
                <button
                  phx-click="increment_quantity"
                  disabled={@quantity >= 10}
                  aria-label="Increase quantity"
                  class="flex h-11 w-11 cursor-pointer items-center justify-center text-[#211D16] hover:bg-[#FAF9F7] disabled:cursor-not-allowed disabled:text-[#C9C2B2] motion-safe:transition-colors"
                >
                  <svg
                    class="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="2"
                    aria-hidden="true"
                  >
                    <path stroke-linecap="round" d="M12 5v14M5 12h14" />
                  </svg>
                </button>
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
            <button
              id="sika-add-to-cart"
              phx-click="add_to_cart"
              disabled={!@purchasable}
              class={[
                "mt-7 flex h-14 w-full items-center justify-center text-[0.75rem] font-semibold uppercase tracking-[0.25em] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-opacity",
                if(@purchasable,
                  do: "cursor-pointer bg-store-accent text-white hover:opacity-90",
                  else: "cursor-not-allowed bg-[#EEEAE2] text-[#9A927F]"
                )
              ]}
            >
              <%= cond do %>
                <% is_nil(@selected_variant) -> %>
                  Select options
                <% !@purchasable -> %>
                  Sold out
                <% true -> %>
                  Add to cart
              <% end %>
            </button>

            <a
              :if={Shared.whatsapp_link(@store, @product.title)}
              href={Shared.whatsapp_link(@store, @product.title)}
              target="_blank"
              rel="noopener noreferrer"
              class="mt-3 flex h-12 w-full items-center justify-center gap-2.5 border border-[#E8E3D9] text-[0.75rem] font-semibold uppercase tracking-[0.2em] text-[#211D16] hover:border-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              <svg
                class="h-4 w-4 text-whatsapp"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
              </svg>
              Enquire on WhatsApp
            </a>

            <details class="group mt-8 border-t border-[#E8E3D9]">
              <summary class="flex cursor-pointer list-none items-center justify-between py-4 text-sm font-semibold text-[#211D16] [&::-webkit-details-marker]:hidden">
                Delivery &amp; returns
                <svg
                  class="h-4 w-4 text-[#6E675C] group-open:rotate-180 motion-safe:transition-transform"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                  />
                </svg>
              </summary>
              <p class="pb-5 text-sm leading-relaxed text-[#6E675C]">
                Delivery and returns are set by this shop — see <a
                  href={store_path(@store.slug, "/policies")}
                  class="underline decoration-[#C2A15B]/60 underline-offset-4 hover:text-[#211D16]"
                >
                  its policies
                </a>.
              </p>
            </details>
          </div>
        </div>

        <section
          :if={@related_products != []}
          class="mt-20"
          aria-labelledby="sika-related-heading"
        >
          <h2
            id="sika-related-heading"
            class="text-center text-2xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]"
          >
            Also in the vitrine
          </h2>
          <Shared.caught_light class="mx-auto mt-4 w-16" />
          <div class="mt-10 grid grid-cols-2 gap-x-6 gap-y-10 sm:grid-cols-3">
            <Shared.piece_card
              :for={related <- Enum.take(@related_products, 3)}
              product={related}
              store={@store}
            />
          </div>
        </section>

        <section :if={assigns[:reviews] != nil} class="mt-20 border-t border-[#E8E3D9] pt-10">
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
      </div>

      <div class="h-16 sm:hidden" aria-hidden="true"></div>
    </div>

    <Shared.footer store={@store} categories={@categories} />
    <Shared.sika_bottom_nav store={@store} cart_count={@cart_count} />
    """
  end

  defp purchasable?(nil), do: false
  defp purchasable?(variant), do: Emakola.Catalog.Variant.in_stock?(variant)
end
