defmodule Emakola.Themes.Starter.Sections.Trust do
  @moduledoc """
  Starter home trust section.

  It shipped promising "Quick delivery within Accra and nationwide shipping
  available" and "Hassle-free returns within 7 days of delivery" — a delivery
  area and a returns window no Starter merchant had set. Starter is the theme a
  brand-new store gets by default, so this was the very first thing most
  Makola storefronts said, and it was not true.

  Delivery is now the store's own (see `Emakola.Themes.Delivery`) and returns
  point at the merchant's policies page.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Starter.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Delivery

  @impl true
  def key, do: "starter/trust"
  @impl true
  def label, do: "Trust"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:delivery_note, Delivery.callout(assigns))
      |> assign(:returns_href, store_path(assigns.store.slug, "/policies#returns"))

    ~H"""
    <section
      :if={section_enabled?(@theme, :trust)}
      class="py-12 bg-[#F8FAFC]"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <h2
          class="text-xl font-semibold text-[#0F172A] text-center mb-8"
          style="font-family: 'Inter', sans-serif;"
        >
          {@theme.trust.title}
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <%!-- Secure Payment --%>
          <div class="text-center p-6">
            <div class="w-12 h-12 rounded-xl bg-[var(--theme-primary,#6366F1)]/10 mx-auto mb-4 flex items-center justify-center">
              <svg
                class="w-6 h-6 text-[var(--theme-primary,#6366F1)]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                />
              </svg>
            </div>
            <h3
              class="text-sm font-semibold text-[#0F172A] mb-1"
              style="font-family: 'Inter', sans-serif;"
            >
              Secure Payment
            </h3>
            <p class="text-xs text-[#64748B]" style="font-family: 'Inter', sans-serif;">
              Mobile money and card payments protected with encryption.
            </p>
          </div>

          <%!-- Fast Delivery --%>
          <div class="text-center p-6">
            <div class="w-12 h-12 rounded-xl bg-[var(--theme-primary,#6366F1)]/10 mx-auto mb-4 flex items-center justify-center">
              <svg
                class="w-6 h-6 text-[var(--theme-primary,#6366F1)]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                />
              </svg>
            </div>
            <h3
              class="text-sm font-semibold text-[#0F172A] mb-1"
              style="font-family: 'Inter', sans-serif;"
            >
              Delivery
            </h3>
            <p
              :if={@delivery_note}
              class="text-xs text-[#64748B]"
              style="font-family: 'Inter', sans-serif;"
            >
              {@delivery_note}
            </p>
            <p
              :if={!@delivery_note}
              class="text-xs text-[#64748B]"
              style="font-family: 'Inter', sans-serif;"
            >
              This store sets its own delivery zones, fees and times.
            </p>
          </div>

          <%!-- Easy Returns --%>
          <div class="text-center p-6">
            <div class="w-12 h-12 rounded-xl bg-[var(--theme-primary,#6366F1)]/10 mx-auto mb-4 flex items-center justify-center">
              <svg
                class="w-6 h-6 text-[var(--theme-primary,#6366F1)]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182"
                />
              </svg>
            </div>
            <h3
              class="text-sm font-semibold text-[#0F172A] mb-1"
              style="font-family: 'Inter', sans-serif;"
            >
              Returns
            </h3>
            <p class="text-xs text-[#64748B]" style="font-family: 'Inter', sans-serif;">
              <a
                href={@returns_href}
                class="underline decoration-[#CBD5E1] underline-offset-2 hover:text-[#0F172A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--theme-primary,#6366F1)] rounded"
              >
                See this store's returns policy
              </a>
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
