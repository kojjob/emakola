defmodule Emakola.Themes.Pace.Sections.About do
  @moduledoc """
  Pace home store story — start-block avatar, description (neutral
  fallback), WhatsApp CTA when the store has a number.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "pace/about"
  @impl true
  def label, do: "About"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section class="px-5 py-4 sm:px-8 sm:py-5 lg:px-10" aria-labelledby="pace-about-heading">
      <div class="mx-auto max-w-[1280px] rounded-[24px] bg-[#F1F6FA] p-6 text-center sm:p-8">
        <div class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-slate-950">
          <span class="pace-display text-2xl font-bold italic text-white">
            {String.first(@store.name)}
          </span>
        </div>
        <h2
          id="pace-about-heading"
          class="pace-display mb-2 text-xl font-bold uppercase italic tracking-tight text-slate-950"
        >
          About the shop
        </h2>
        <p class="mx-auto mb-4 max-w-[480px] text-sm leading-relaxed text-slate-600">
          {if @store.description,
            do: @store.description,
            else: "Welcome to #{@store.name}. Browse the lineup — quality gear, picked for you."}
        </p>
        <a
          :if={Map.get(@store, :whatsapp_number)}
          href={"https://wa.me/#{@store.whatsapp_number}"}
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex min-h-[44px] items-center gap-2 rounded-full bg-whatsapp px-5 py-2.5 text-sm font-semibold text-white hover:bg-whatsapp-dark focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
        >
          <svg class="h-4 w-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
            <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
          </svg>
          Chat on WhatsApp
        </a>
      </div>
    </section>
    """
  end
end
