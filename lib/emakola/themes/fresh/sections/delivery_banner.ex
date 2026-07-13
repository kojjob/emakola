defmodule Emakola.Themes.Fresh.Sections.DeliveryBanner do
  @moduledoc """
  Fresh home delivery banner — the theme's `:promo` block.

  It used to headline "Same-Day Delivery in Accra" and promise "Order before
  noon and get your fresh produce delivered the same day. Quality guaranteed."
  on every Fresh storefront — including a merchant in Tamale who had never
  delivered to Accra and never offered a noon cutoff. There is no cutoff field
  to derive one from, so the cutoff is gone entirely.

  The banner now states the store's OWN delivery zones (see
  `Emakola.Themes.Delivery`): a store that has configured same-day Accra
  delivery still says so, and a store that has configured nothing says nothing
  and points at its policies page instead.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Delivery
  alias Emakola.Themes.Fresh.Shared

  @impl true
  def key, do: "fresh/delivery_banner"
  @impl true
  def label, do: "Delivery Banner"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    zones = Delivery.zones(assigns)

    assigns =
      assigns
      |> assign(:estimate, Delivery.estimate(zones))
      |> assign(:zone_names, Delivery.zone_names(zones))
      |> assign(:free_delivery, Delivery.free_delivery_detail(zones, assigns.store.currency))
      |> assign(:policies_href, store_path(assigns.store.slug, "/policies#shipping"))

    ~H"""
    <section :if={Shared.section_enabled?(@theme, :promo)} class="py-8">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="relative rounded-3xl overflow-hidden bg-[#ECFDF5]">
          <div class="px-6 sm:px-10 py-10 sm:py-14">
            <div class="flex items-center gap-3 mb-4">
              <svg
                class="w-8 h-8 text-[#059669]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                />
              </svg>
              <h3
                class="text-2xl sm:text-3xl font-bold text-cta-dark"
                style="font-family: 'Nunito', sans-serif;"
              >
                {if @zone_names, do: "We deliver to #{@zone_names}", else: "Delivery & returns"}
              </h3>
            </div>

            <p
              class="text-[#78350F] text-base mb-8 max-w-lg"
              style="font-family: 'Inter', sans-serif;"
            >
              <%= if @zone_names do %>
                {if(@free_delivery,
                  do: "Free delivery — #{@free_delivery}.",
                  else: "Delivery fees and times are set by this store."
                )}
              <% else %>
                This store sets its own delivery times and returns terms.
                <a
                  href={@policies_href}
                  class="font-semibold underline decoration-[#059669]/40 underline-offset-2 hover:text-cta-dark focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#059669] rounded"
                >
                  See its policies
                </a>
              <% end %>
            </p>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.tile :if={@estimate} title={@estimate} subtitle={@zone_names}>
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </.tile>

              <.tile :if={@free_delivery} title="Free delivery" subtitle={@free_delivery}>
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </.tile>

              <.tile
                :if={!@estimate && !@free_delivery}
                title="Delivery & returns"
                subtitle="See this store's policies"
                href={@policies_href}
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </.tile>

              <.tile title="Secure payment" subtitle="MoMo, Telecel Cash & card">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
                />
              </.tile>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :href, :string, default: nil
  slot :inner_block, required: true

  defp tile(assigns) do
    ~H"""
    <div class="flex items-center gap-3 bg-white rounded-2xl p-4 shadow-sm">
      <div class="w-10 h-10 rounded-full bg-[#059669]/10 flex items-center justify-center flex-shrink-0">
        <svg
          class="w-5 h-5 text-[#059669]"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          {render_slot(@inner_block)}
        </svg>
      </div>
      <div class="min-w-0">
        <p class="text-sm font-bold text-cta-dark" style="font-family: 'Nunito', sans-serif;">
          {@title}
        </p>
        <a
          :if={@href && @subtitle}
          href={@href}
          class="text-xs text-[#78350F] underline decoration-[#78350F]/30 underline-offset-2 hover:text-cta-dark focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#059669] rounded"
          style="font-family: 'Inter', sans-serif;"
        >
          {@subtitle}
        </a>
        <p
          :if={!@href && @subtitle}
          class="text-xs text-[#78350F]"
          style="font-family: 'Inter', sans-serif;"
        >
          {@subtitle}
        </p>
      </div>
    </div>
    """
  end
end
