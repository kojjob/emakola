defmodule Emakola.Themes.Vibrant.Sections.ServiceStrip do
  @moduledoc """
  Vibrant service strip — the five-icon trust row that closes the page, above
  the footer.

  Ungated on the pre-section home: no theme toggle ever hid it. Merchants can
  now remove or reorder it from the section editor, which is the first control
  they have ever had over it.

  The pills state delivery, returns and support promises that ship with the
  theme rather than coming from the merchant's own policies — see the retrofit
  notes; moved verbatim, deliberately unchanged.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "vibrant/service_strip"

  @impl true
  def label, do: "Service strip"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section class="bg-white border-t border-[#E7E5E4]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4 sm:gap-6">
          <.service_pill icon="local_shipping" title="Free delivery" subtitle="Orders over GH₵200" />
          <.service_pill
            icon="account_balance_wallet"
            title="Mobile money"
            subtitle="MoMo, Vodafone, Card"
          />
          <.service_pill icon="chat" title="WhatsApp support" subtitle="Reply within an hour" />
          <.service_pill icon="verified" title="Authenticated" subtitle="Every item, every time" />
          <.service_pill icon="cached" title="Easy returns" subtitle="14-day window" />
        </div>
      </div>
    </section>
    """
  end

  # ── Service Pill (private) ──

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true

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
        <p class="text-xs text-[#78716C] mt-0.5 leading-snug">
          {@subtitle}
        </p>
      </div>
    </div>
    """
  end
end
