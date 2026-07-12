defmodule Emakola.Themes.Sika.Sections.Assurance do
  @moduledoc """
  Sika home assurance strip — quiet, text-only, promise-free.

  Names only the payment rails the platform really supports, rendered as
  hallmark stamps (a rail named on the page is a mark punched into metal:
  only true facts get a stamp). Delivery and returns defer to the store's
  own policies page — no invented SLA — and questions go to the
  merchant's WhatsApp when configured, their contact page otherwise.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Sika.Shared

  @rails ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"]

  @impl true
  def key, do: "sika/assurance"
  @impl true
  def label, do: "Assurance"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Good to know"}]
  end

  @impl true
  def render(assigns) do
    support_href =
      case Map.get(assigns.store, :whatsapp_number) do
        number when is_binary(number) and number != "" -> "https://wa.me/#{number}"
        _ -> store_path(assigns.store.slug, "/contact")
      end

    assigns =
      assigns
      |> assign(:heading, Shared.present(assigns.settings["heading"]) || "Good to know")
      |> assign(:support_href, support_href)
      |> assign(:support_external, String.starts_with?(support_href, "https://"))
      |> assign(:rails, @rails)

    ~H"""
    <section class="px-4 py-10 sm:px-6 sm:py-14 lg:px-8" aria-labelledby="sika-assurance-heading">
      <div class="mx-auto max-w-[1200px] border-y border-[#E8E3D9] py-10 sm:py-12">
        <h2
          id="sika-assurance-heading"
          class="text-center text-[0.6875rem] font-semibold uppercase tracking-[0.25em] text-[#6E675C]"
        >
          {@heading}
        </h2>

        <div class="mt-8 grid gap-8 text-center sm:grid-cols-3">
          <div>
            <p class="text-sm font-semibold text-[#211D16]">Secure checkout</p>
            <p class="mt-1 text-xs leading-relaxed text-[#6E675C]">
              Payments are processed securely.
            </p>
          </div>
          <div>
            <p class="text-sm font-semibold text-[#211D16]">Delivery &amp; returns</p>
            <a
              href={store_path(@store.slug, "/policies#shipping")}
              class="mt-1 inline-block text-xs font-medium text-[#6E675C] underline decoration-[#C2A15B]/60 underline-offset-4 hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16]"
            >
              This store's policies
            </a>
          </div>
          <div>
            <p class="text-sm font-semibold text-[#211D16]">Questions?</p>
            <a
              href={@support_href}
              {if @support_external, do: [target: "_blank", rel: "noopener noreferrer"], else: []}
              class="mt-1 inline-block text-xs font-medium text-[#6E675C] underline decoration-[#C2A15B]/60 underline-offset-4 hover:text-[#211D16] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16]"
            >
              {if @support_external, do: "Message the shop on WhatsApp", else: "Contact the shop"}
            </a>
          </div>
        </div>

        <div class="mt-10 text-center">
          <p class="text-[0.625rem] font-semibold uppercase tracking-[0.25em] text-[#6E675C]">
            We accept
          </p>
          <ul
            class="mt-4 flex flex-wrap items-center justify-center gap-2"
            aria-label="Payment methods"
          >
            <li :for={rail <- @rails}>
              <Shared.hallmark>{rail}</Shared.hallmark>
            </li>
          </ul>
        </div>
      </div>
    </section>
    """
  end
end
