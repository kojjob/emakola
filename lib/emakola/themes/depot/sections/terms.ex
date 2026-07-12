defmodule Emakola.Themes.Depot.Sections.Terms do
  @moduledoc """
  Depot home trade terms — commercial trust, not emotional trust.

  Names only the payment rails the platform really supports (Paystack
  Ghana mobile money: MTN MoMo, Telecel Cash, AirtelTigo Money, plus
  card). Deliberately promise-free: delivery and returns link to the
  store's own policies page rather than hardcoding an SLA the merchant
  never wrote, and trade inquiries go to the merchant's WhatsApp when
  configured, their contact page otherwise.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "depot/terms"
  @impl true
  def label, do: "Trade terms"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "How ordering works"}]
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
      class="bg-zinc-50 px-4 py-6 sm:px-6 sm:py-8 lg:px-8"
      aria-labelledby="depot-terms-heading"
    >
      <div class="mx-auto max-w-[1120px] border-2 border-zinc-900 bg-white">
        <h2
          id="depot-terms-heading"
          class="border-b-2 border-zinc-900 px-5 py-4 text-lg font-bold tracking-tight text-zinc-900 [font-family:var(--dt-heading-font,inherit)]"
        >
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "How ordering works"}
        </h2>

        <div class="grid divide-y divide-zinc-200 sm:grid-cols-3 sm:divide-x sm:divide-y-0">
          <div class="px-5 py-5">
            <p class="mb-1 font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.16em] text-zinc-500">
              01 — Pay
            </p>
            <p class="text-sm font-semibold text-zinc-900">Pay on your phone</p>
            <p class="mt-1 text-xs leading-relaxed text-zinc-600">
              Mobile money or card at checkout — payments processed securely.
            </p>
          </div>

          <div class="px-5 py-5">
            <p class="mb-1 font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.16em] text-zinc-500">
              02 — Receive
            </p>
            <p class="text-sm font-semibold text-zinc-900">Delivery &amp; returns</p>
            <a
              href={store_path(@store.slug, "/policies#shipping")}
              class="mt-1 inline-block text-xs font-medium text-zinc-600 underline decoration-zinc-300 underline-offset-2 hover:text-zinc-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900"
            >
              See this store's policies
            </a>
          </div>

          <div class="px-5 py-5">
            <p class="mb-1 font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.16em] text-zinc-500">
              03 — Talk
            </p>
            <p class="text-sm font-semibold text-zinc-900">Trade inquiries</p>
            <a
              href={@support_href}
              {if String.starts_with?(@support_href, "https://"), do: [target: "_blank", rel: "noopener noreferrer"], else: []}
              class="mt-1 inline-block text-xs font-medium text-zinc-600 underline decoration-zinc-300 underline-offset-2 hover:text-zinc-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900"
            >
              {if String.starts_with?(@support_href, "https://"),
                do: "Message the supplier on WhatsApp",
                else: "Contact the store"}
            </a>
          </div>
        </div>

        <div class="border-t border-zinc-200 px-5 py-4">
          <p class="mb-2.5 font-mono text-[10px] font-semibold uppercase tracking-[0.2em] text-zinc-500">
            We accept
          </p>
          <ul class="flex flex-wrap items-center gap-2" aria-label="Payment methods">
            <li
              :for={rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]}
              class="inline-flex items-center border border-zinc-200 bg-zinc-50 px-2.5 py-1 text-[11px] font-bold tracking-wide text-zinc-800"
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
