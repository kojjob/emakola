defmodule Emakola.Themes.Dede.Sections.Special do
  @moduledoc """
  Today's special — the dish chalked at the top of the board.

  Features the first *available* product (sold-out dishes never headline)
  with the fastest possible order: price, one-tap add, and WhatsApp when
  the store has a number. Renders nothing when no dish is available — the
  menu section owns the empty state. The board below lists every other
  dish, so the special is chalked once on the page (`Shared.special/1`).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Dede.Shared
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def key, do: "dede/special"
  @impl true
  def label, do: "Today's special"

  @impl true
  def settings_schema do
    [%{key: "label", type: :string, label: "Tag", default: "Today's special"}]
  end

  @impl true
  def render(assigns) do
    special = Shared.special(assigns.products)

    assigns =
      assigns
      |> assign(:special, special)
      |> assign(:image, special && Shared.first_image(special))
      |> assign(:whatsapp, special && Shared.whatsapp_link(assigns.store, special.title))
      |> assign(:tag, tag_label(assigns.settings["label"]))

    ~H"""
    <section
      :if={@special}
      id="dede-special"
      class="px-4 pt-4 sm:px-6 sm:pt-6 lg:px-8"
      aria-labelledby="dede-special-heading"
    >
      <div class="mx-auto max-w-[880px]">
        <div class="rounded-2xl border-2 border-[#26211A]/80 bg-[#FFFDF6] p-5 sm:p-7">
          <span class="inline-block -rotate-2 bg-store-accent px-3 py-1.5 text-[0.6875rem] font-bold uppercase tracking-[0.18em] text-white">
            {@tag}
          </span>
          <div class="mt-4 flex items-start gap-4">
            <.optimized_image
              :if={@image}
              src={@image}
              alt={@special.title}
              width={96}
              height={96}
              class="h-20 w-20 flex-shrink-0 rounded-full border-2 border-[#26211A]/15 object-cover sm:h-24 sm:w-24"
            />
            <Shared.dish_placeholder :if={!@image} class="h-20 w-20 sm:h-24 sm:w-24" />
            <div class="min-w-0 flex-1">
              <h2
                id="dede-special-heading"
                class="text-2xl uppercase leading-tight tracking-wide text-[#26211A] [font-family:var(--dt-heading-font,'Anton',sans-serif)] sm:text-3xl"
              >
                <a
                  href={store_path(@store.slug, "/products/#{@special.slug}")}
                  class="rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2"
                >
                  {@special.title}
                </a>
              </h2>
              <p
                :if={@special.description}
                class="mt-1.5 text-sm leading-relaxed text-[#6B6355] line-clamp-2"
              >
                {@special.description}
              </p>
            </div>
          </div>
          <div class="mt-5 flex flex-wrap items-center gap-x-4 gap-y-3">
            <span class="text-3xl font-bold tabular-nums text-[#26211A]">
              {Currency.format_price_range(@special.min_price, @special.max_price, @store.currency)}
            </span>
            <button
              type="button"
              phx-click="add_to_cart"
              phx-value-product-id={@special.id}
              class="inline-flex min-h-12 cursor-pointer items-center gap-2 rounded-full bg-store-accent px-6 text-[0.9375rem] font-bold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
              aria-label={"Add #{@special.title} to your order"}
            >
              Add to order
            </button>
            <a
              :if={@whatsapp}
              href={@whatsapp}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex min-h-12 items-center gap-2 rounded-full border-2 border-whatsapp px-5 text-sm font-bold text-whatsapp hover:bg-whatsapp/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              <svg class="h-4.5 w-4.5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d={Shared.whatsapp_glyph()} />
              </svg>
              Order on WhatsApp
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp tag_label(label) when is_binary(label) do
    if String.trim(label) == "", do: "Today's special", else: label
  end

  defp tag_label(_label), do: "Today's special"
end
