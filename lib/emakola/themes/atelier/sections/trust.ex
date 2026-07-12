defmodule Emakola.Themes.Atelier.Sections.Trust do
  @moduledoc "Atelier home trust / payment section -- extracted verbatim from atelier/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Atelier.Shared

  @impl true
  def key, do: "atelier/trust"
  @impl true
  def label, do: "Trust"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :trust)}
      id="trust-section"
      class="py-14 sm:py-20 bg-[#FAFAF9]"
      phx-hook="ScrollReveal"
    >
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- 3 big icons, 1-word labels — visual first --%>
        <div class="grid grid-cols-3 gap-4 sm:gap-8 mb-12 sm:mb-16 reveal-up">
          <div class="flex flex-col items-center text-center group cursor-default">
            <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#059669]/10 flex items-center justify-center mb-3 group-hover:bg-[#059669]/15 group-hover:scale-110 transition-all duration-300">
              <svg
                class="w-8 h-8 sm:w-10 sm:h-10 text-[#059669]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                />
              </svg>
            </div>
            <span class="text-sm sm:text-base font-semibold text-cta-dark">Safe</span>
            <span class="text-[11px] sm:text-xs text-[#78716C] mt-0.5">Secure checkout</span>
          </div>
          <div class="flex flex-col items-center text-center group cursor-default">
            <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-store-accent/10 flex items-center justify-center mb-3 group-hover:bg-store-accent/15 group-hover:scale-110 transition-all duration-300">
              <svg
                class="w-8 h-8 sm:w-10 sm:h-10 text-store-accent"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z"
                />
              </svg>
            </div>
            <span class="text-sm sm:text-base font-semibold text-cta-dark">Fast</span>
            <span class="text-[11px] sm:text-xs text-[#78716C] mt-0.5">Instant confirmation</span>
          </div>
          <div class="flex flex-col items-center text-center group cursor-default">
            <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#7C3AED]/10 flex items-center justify-center mb-3 group-hover:bg-[#7C3AED]/15 group-hover:scale-110 transition-all duration-300">
              <svg
                class="w-8 h-8 sm:w-10 sm:h-10 text-[#7C3AED]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
                />
              </svg>
            </div>
            <span class="text-sm sm:text-base font-semibold text-cta-dark">Easy</span>
            <span class="text-[11px] sm:text-xs text-[#78716C] mt-0.5">Pay with your phone</span>
          </div>
        </div>
        <div class="border-t border-[#E7E5E4] mb-10 sm:mb-14 reveal-up"></div>
        <div class="reveal-up">
          <p class="text-center text-xs font-semibold uppercase tracking-[0.2em] text-[#78716C] mb-6">
            We Accept
          </p>
          <div class="flex items-center justify-center gap-3 sm:gap-4 flex-wrap">
            <div class="flex items-center gap-2.5 bg-[#FBBF24]/10 border border-[#FBBF24]/25 rounded-full px-5 py-3 hover:bg-[#FBBF24]/15 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#FBBF24]"></div>
              <span class="text-sm font-bold text-[#92400E]">MTN MoMo</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#EF4444]/8 border border-[#EF4444]/20 rounded-full px-5 py-3 hover:bg-[#EF4444]/12 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#EF4444]"></div>
              <span class="text-sm font-bold text-[#991B1B]">Telecel Cash</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#3B82F6]/8 border border-[#3B82F6]/20 rounded-full px-5 py-3 hover:bg-[#3B82F6]/12 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#3B82F6]"></div>
              <span class="text-sm font-bold text-[#1E40AF]">Visa</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#F97316]/8 border border-[#F97316]/20 rounded-full px-5 py-3 hover:bg-[#F97316]/12 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#F97316]"></div>
              <span class="text-sm font-bold text-[#9A3412]">Mastercard</span>
            </div>
          </div>
        </div>
      </div>
      <style>
        .reveal-up { opacity: 0; transform: translateY(24px); transition: opacity 0.6s ease-out, transform 0.6s ease-out; }
        .reveal-up.revealed { opacity: 1; transform: translateY(0); }
      </style>
    </section>
    """
  end
end
