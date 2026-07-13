defmodule Emakola.Themes.Vibrant.Sections.ServiceStrip do
  @moduledoc """
  Vibrant service strip — the trust row that closes the page, above the footer.

  It used to promise "Free delivery — Orders over GH₵200", "WhatsApp support —
  Reply within an hour", "Easy returns — 14-day window" and "Authenticated —
  Every item, every time". The merchant wrote none of that, could not edit it,
  and a store selling from a bedroom in Tamale was promising an hour's reply
  and a fortnight's returns to everyone who scrolled.

  Now the delivery pill states the store's OWN zones (see
  `Emakola.Themes.Delivery`) and says nothing when it has configured none —
  falling back to the merchant's policies page, which is authoritative. The
  payment rails are stated because the platform really does support them.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Delivery

  @impl true
  def key, do: "vibrant/service_strip"

  @impl true
  def label, do: "Service strip"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    zones = Delivery.zones(assigns)

    assigns =
      assigns
      |> assign(:free_delivery, Delivery.free_delivery_detail(zones, assigns.store.currency))
      |> assign(:estimate, Delivery.estimate(zones))
      |> assign(:zone_names, Delivery.zone_names(zones))
      |> assign(:policies_href, store_path(assigns.store.slug, "/policies#shipping"))
      |> assign(:support_href, support_href(assigns.store))

    ~H"""
    <section class="bg-white border-t border-[#E7E5E4]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
          <%!-- The merchant's own zones, or nothing but a pointer to their policies. --%>
          <.service_pill
            :if={@free_delivery}
            icon="local_shipping"
            title="Free delivery"
            subtitle={@free_delivery}
          />
          <.service_pill
            :if={!@free_delivery && @estimate}
            icon="local_shipping"
            title={@estimate}
            subtitle={@zone_names}
          />
          <.service_pill
            :if={!@free_delivery && !@estimate}
            icon="local_shipping"
            title="Delivery & returns"
            subtitle="See this store's policies"
            href={@policies_href}
          />

          <.service_pill
            icon="account_balance_wallet"
            title="Mobile money"
            subtitle="MTN MoMo, Telecel Cash, AirtelTigo, card"
          />
          <.service_pill
            icon="lock"
            title="Secure checkout"
            subtitle="Payments processed securely"
          />
          <.service_pill
            icon="chat"
            title="Questions?"
            subtitle={
              if String.starts_with?(@support_href, "https://"),
                do: "Chat with the seller on WhatsApp",
                else: "Contact the shop"
            }
            href={@support_href}
          />
        </div>
      </div>
    </section>
    """
  end

  defp support_href(store) do
    case Map.get(store, :whatsapp_number) do
      number when is_binary(number) and number != "" -> "https://wa.me/#{number}"
      _ -> store_path(store.slug, "/contact")
    end
  end

  # ── Service Pill (private) ──

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :href, :string, default: nil

  defp service_pill(assigns) do
    ~H"""
    <div class="flex items-start gap-3">
      <span class="flex-shrink-0 w-10 h-10 rounded-full bg-[#FEF3C7] flex items-center justify-center">
        <span class="material-symbols-outlined text-[20px] text-[var(--theme-primary,#B45309)]">
          {@icon}
        </span>
      </span>
      <div class="min-w-0">
        <p
          class="text-sm font-bold text-[#1C1917] leading-tight"
          style="font-family: 'Manrope', sans-serif;"
        >
          {@title}
        </p>
        <a
          :if={@href && @subtitle}
          href={@href}
          {if String.starts_with?(@href, "https://"), do: [target: "_blank", rel: "noopener noreferrer"], else: []}
          class="text-xs text-[#78716C] mt-0.5 leading-snug underline decoration-[#D6D3D1] underline-offset-2 hover:text-[#1C1917] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#1C1917] rounded"
        >
          {@subtitle}
        </a>
        <p :if={!@href && @subtitle} class="text-xs text-[#78716C] mt-0.5 leading-snug">
          {@subtitle}
        </p>
      </div>
    </div>
    """
  end
end
