defmodule Emakola.Themes.Fie.Sections.Trust do
  @moduledoc """
  Fie home trust index — the payment rails the platform really supports
  (Paystack Ghana mobile money: MTN MoMo, Telecel Cash, AirtelTigo Money,
  plus card), secure checkout, and where delivery/returns and support
  actually live.

  Deliberately promise-free: delivery and returns link to the store's own
  policies page rather than hardcoding an SLA the merchant never wrote
  (see NoInventedPolicyCopyTest), and support goes to the merchant's
  WhatsApp when configured, their contact page otherwise.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fie.Shared

  @impl true
  def key, do: "fie/trust"
  @impl true
  def label, do: "Trust"

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
        Shared.wa_me(assigns.store) || store_path(assigns.store.slug, "/contact")
      )

    ~H"""
    <section class="border-t border-[#EBDAD3] bg-[#FDFCFB]" aria-labelledby="fie-trust-heading">
      <div class="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <h2
          id="fie-trust-heading"
          class="mb-8 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500"
        >
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "Shop with confidence"}
        </h2>

        <div class="grid grid-cols-1 gap-px border border-[#EBDAD3] bg-[#EBDAD3] sm:grid-cols-3">
          <div class="bg-[#FDFCFB] p-6">
            <svg
              class="mb-3 h-5 w-5 text-stone-900"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.6"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
              />
            </svg>
            <p class="text-sm font-semibold text-stone-900">Secure checkout</p>
            <p class="mt-1 text-xs leading-relaxed text-stone-600">
              Payments processed securely
            </p>
          </div>

          <div class="bg-[#FDFCFB] p-6">
            <svg
              class="mb-3 h-5 w-5 text-stone-900"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.6"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
              />
            </svg>
            <p class="text-sm font-semibold text-stone-900">Delivery &amp; returns</p>
            <a
              href={store_path(@store.slug, "/policies#shipping")}
              class="mt-1 inline-block text-xs font-medium text-stone-600 underline decoration-[#D8BCB0] underline-offset-2 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
            >
              See this store's policies
            </a>
          </div>

          <div class="bg-[#FDFCFB] p-6">
            <svg
              class="mb-3 h-5 w-5 text-stone-900"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.6"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"
              />
            </svg>
            <p class="text-sm font-semibold text-stone-900">Questions?</p>
            <a
              href={@support_href}
              {if String.starts_with?(@support_href, "https://"), do: [target: "_blank", rel: "noopener noreferrer"], else: []}
              class="mt-1 inline-block text-xs font-medium text-stone-600 underline decoration-[#D8BCB0] underline-offset-2 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
            >
              {if String.starts_with?(@support_href, "https://"),
                do: "Chat with the seller on WhatsApp",
                else: "Contact the shop"}
            </a>
          </div>
        </div>

        <div class="mt-6 flex flex-wrap items-center gap-2">
          <span class="mr-2 text-[10px] font-semibold uppercase tracking-[0.2em] text-stone-500">
            We accept
          </span>
          <ul class="flex flex-wrap items-center gap-2" aria-label="Payment methods">
            <li
              :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}
              class="inline-flex items-center border border-[#EBDAD3] bg-[#F7ECE7] px-2.5 py-1 text-[10px] font-semibold tracking-wide text-stone-700"
            >
              {rail}
            </li>
          </ul>
        </div>
      </div>
    </section>
    """
  end
end
