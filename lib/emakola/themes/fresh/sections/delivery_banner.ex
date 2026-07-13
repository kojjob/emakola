defmodule Emakola.Themes.Fresh.Sections.DeliveryBanner do
  @moduledoc """
  Fresh home delivery banner — the theme's `:promo` block. Extracted verbatim
  from `fresh/home.ex`, including the three feature tiles.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Fresh.Shared

  @impl true
  def key, do: "fresh/delivery_banner"
  @impl true
  def label, do: "Delivery Banner"

  # No settings: the heading and feature tiles are static template text, kept
  # verbatim so the storefront's output is unchanged.
  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
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
                Same-Day Delivery in Accra
              </h3>
            </div>
            <p
              class="text-[#78350F] text-base mb-8 max-w-lg"
              style="font-family: 'Inter', sans-serif;"
            >
              Order before noon and get your fresh produce delivered the same day. Quality guaranteed.
            </p>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div class="flex items-center gap-3 bg-white rounded-2xl p-4 shadow-sm">
                <div class="w-10 h-10 rounded-full bg-[#059669]/10 flex items-center justify-center flex-shrink-0">
                  <svg
                    class="w-5 h-5 text-[#059669]"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </div>
                <div>
                  <p
                    class="text-sm font-bold text-cta-dark"
                    style="font-family: 'Nunito', sans-serif;"
                  >
                    Fresh Guarantee
                  </p>
                  <p class="text-xs text-[#78350F]" style="font-family: 'Inter', sans-serif;">
                    Quality checked produce
                  </p>
                </div>
              </div>
              <div class="flex items-center gap-3 bg-white rounded-2xl p-4 shadow-sm">
                <div class="w-10 h-10 rounded-full bg-[#059669]/10 flex items-center justify-center flex-shrink-0">
                  <svg
                    class="w-5 h-5 text-[#059669]"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </div>
                <div>
                  <p
                    class="text-sm font-bold text-cta-dark"
                    style="font-family: 'Nunito', sans-serif;"
                  >
                    Same Day Delivery
                  </p>
                  <p class="text-xs text-[#78350F]" style="font-family: 'Inter', sans-serif;">
                    Order before 12pm
                  </p>
                </div>
              </div>
              <div class="flex items-center gap-3 bg-white rounded-2xl p-4 shadow-sm">
                <div class="w-10 h-10 rounded-full bg-[#059669]/10 flex items-center justify-center flex-shrink-0">
                  <svg
                    class="w-5 h-5 text-[#059669]"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M9 12.75L11.25 15 15 9.75m-6-7.19l-2.12 2.12a1.5 1.5 0 01-1.061.44H4.5A2.25 2.25 0 002.25 9v1.069c0 .398.158.78.44 1.06l2.12 2.122c.282.281.44.663.44 1.06V16.5a2.25 2.25 0 002.25 2.25h1.069c.397 0 .78.158 1.06.44l2.122 2.12a1.5 1.5 0 002.12 0l2.122-2.12a1.5 1.5 0 011.06-.44H18.75A2.25 2.25 0 0021 16.5v-1.069a1.5 1.5 0 01.44-1.06l2.12-2.122a1.5 1.5 0 000-2.12l-2.12-2.122a1.5 1.5 0 01-.44-1.06V4.5A2.25 2.25 0 0018.75 2.25h-1.069a1.5 1.5 0 01-1.06-.44l-2.122-2.12a1.5 1.5 0 00-2.12 0z"
                    />
                  </svg>
                </div>
                <div>
                  <p
                    class="text-sm font-bold text-cta-dark"
                    style="font-family: 'Nunito', sans-serif;"
                  >
                    Secure Payment
                  </p>
                  <p class="text-xs text-[#78350F]" style="font-family: 'Inter', sans-serif;">
                    MoMo, Card & Cash
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
