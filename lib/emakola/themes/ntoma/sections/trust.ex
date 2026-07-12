defmodule Emakola.Themes.Ntoma.Sections.Trust do
  @moduledoc """
  Ntoma trust-badge strip — payments, delivery, and support in one compact
  band under the hero, per the locked reference.

  Deliberately promise-free: it names only the payment rails the platform
  really supports (Paystack Ghana mobile money plus card), points delivery
  and returns at the store's own policies page rather than hardcoding an
  SLA the merchant never wrote (see NoInventedPolicyCopyTest), and routes
  questions to the merchant's WhatsApp when configured, their contact page
  otherwise.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "ntoma/trust"
  @impl true
  def label, do: "Trust strip"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Shop with confidence"}]
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :support_href,
        case Map.get(assigns.store, :whatsapp_number) do
          number when is_binary(number) and number != "" -> "https://wa.me/#{number}"
          _ -> store_path(assigns.store.slug, "/contact")
        end
      )

    ~H"""
    <section
      class="border-b border-[#E6D5B8] bg-[#FFFBF2]"
      aria-labelledby="ntoma-trust-heading"
    >
      <div class="mx-auto max-w-[1280px] px-4 py-7 sm:px-6 lg:px-8">
        <h2
          id="ntoma-trust-heading"
          class="mb-6 text-center text-[0.6875rem] font-bold uppercase tracking-[0.24em] text-[#7A6248]"
        >
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "Shop with confidence"}
        </h2>

        <div class="grid gap-6 text-center sm:grid-cols-3 sm:gap-0 sm:divide-x sm:divide-[#E6D5B8]">
          <div class="flex flex-col items-center gap-2 sm:px-6">
            <span class="text-sm font-semibold text-[#2B1708]">Pay your way</span>
            <ul
              class="flex flex-wrap items-center justify-center gap-1.5"
              aria-label="Payment methods"
            >
              <li
                :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}
                class="inline-flex items-center border border-[#E6D5B8] bg-[#FAF4EA] px-2 py-0.5 text-[10px] font-bold tracking-wide text-[#2B1708]"
              >
                {rail}
              </li>
            </ul>
          </div>

          <div class="flex flex-col items-center gap-2 sm:px-6">
            <span class="text-sm font-semibold text-[#2B1708]">Delivery &amp; returns</span>
            <a
              href={store_path(@store.slug, "/policies#shipping")}
              class="text-xs font-medium text-[#7A6248] underline decoration-[#CFB183] underline-offset-2 hover:text-[#2B1708] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708]"
            >
              See this store's policies
            </a>
          </div>

          <div class="flex flex-col items-center gap-2 sm:px-6">
            <span class="text-sm font-semibold text-[#2B1708]">Questions?</span>
            <a
              href={@support_href}
              {if String.starts_with?(@support_href, "https://"), do: [target: "_blank", rel: "noopener noreferrer"], else: []}
              class="text-xs font-medium text-[#7A6248] underline decoration-[#CFB183] underline-offset-2 hover:text-[#2B1708] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708]"
            >
              {if String.starts_with?(@support_href, "https://"),
                do: "Chat with the seller on WhatsApp",
                else: "Contact the shop"}
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
