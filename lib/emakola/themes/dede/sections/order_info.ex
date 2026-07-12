defmodule Emakola.Themes.Dede.Sections.OrderInfo do
  @moduledoc """
  How to order — WhatsApp first, the payment rails the platform really
  supports (Paystack Ghana mobile money: MTN MoMo, Telecel Cash, AirtelTigo
  Money, plus card), and where delivery/pickup answers actually live.

  Deliberately promise-free: delivery points to the store's own policies
  page rather than hardcoding an SLA the merchant never wrote, and the
  order channel goes to the merchant's WhatsApp when configured, their
  contact page otherwise.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Dede.Shared

  @impl true
  def key, do: "dede/order_info"
  @impl true
  def label, do: "How to order"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "How to order"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :whatsapp, Shared.whatsapp_link(assigns.store))

    ~H"""
    <section
      id="dede-order-info"
      class="px-4 py-4 sm:px-6 sm:py-6 lg:px-8"
      aria-labelledby="dede-order-info-heading"
    >
      <div class="mx-auto max-w-[880px] rounded-2xl border-2 border-[#26211A]/15 bg-white p-6 sm:p-8">
        <h2
          id="dede-order-info-heading"
          class="text-xl uppercase tracking-wide text-[#26211A] [font-family:var(--dt-heading-font,'Anton',sans-serif)]"
        >
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "How to order"}
        </h2>

        <div class="mt-5 grid gap-6 sm:grid-cols-3">
          <div>
            <p class="text-sm font-bold text-[#26211A]">Order ahead</p>
            <a
              :if={@whatsapp}
              href={@whatsapp}
              target="_blank"
              rel="noopener noreferrer"
              class="mt-1 inline-flex min-h-11 items-center gap-2 rounded text-sm font-semibold text-whatsapp underline decoration-whatsapp/40 underline-offset-2 hover:decoration-whatsapp focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A]"
            >
              <svg class="h-4 w-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d={Shared.whatsapp_glyph()} />
              </svg>
              Chat with us on WhatsApp
            </a>
            <a
              :if={!@whatsapp}
              href={store_path(@store.slug, "/contact")}
              class="mt-1 inline-flex min-h-11 items-center rounded text-sm font-semibold text-[#6B6355] underline decoration-[#26211A]/30 underline-offset-2 hover:text-[#26211A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A]"
            >
              Contact the shop
            </a>
          </div>

          <div>
            <p class="text-sm font-bold text-[#26211A]">Pay your way</p>
            <ul class="mt-2 flex flex-wrap gap-1.5" aria-label="Payment methods">
              <li
                :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}
                class="inline-flex items-center rounded border border-[#26211A]/20 bg-[#FAF5EA] px-2 py-1 text-[11px] font-bold tracking-wide text-[#26211A]"
              >
                {rail}
              </li>
            </ul>
          </div>

          <div>
            <p class="text-sm font-bold text-[#26211A]">Delivery &amp; pickup</p>
            <a
              href={store_path(@store.slug, "/policies#shipping")}
              class="mt-1 inline-flex min-h-11 items-center rounded text-sm font-semibold text-[#6B6355] underline decoration-[#26211A]/30 underline-offset-2 hover:text-[#26211A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A]"
            >
              See this shop's policies
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
