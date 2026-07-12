defmodule Emakola.Themes.Fie.Sections.Story do
  @moduledoc """
  Fie home story — the shop's note inside the blush frame.

  Store description with a neutral fallback (no invented prose about the
  merchant), and a WhatsApp CTA only when the store actually has a
  number.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Fie.Shared

  @impl true
  def key, do: "fie/story"
  @impl true
  def label, do: "Story"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "About the shop"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="bg-[#FDFCFB]" aria-labelledby="fie-story-heading">
      <div class="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <div class="border border-[#EBDAD3] bg-[#F7ECE7] px-6 py-10 sm:px-10 sm:py-14 lg:grid lg:grid-cols-[1fr_2fr] lg:gap-12">
          <div class="mb-6 lg:mb-0">
            <p class="mb-2 text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500">
              {@store.name}
            </p>
            <h2
              id="fie-story-heading"
              class="text-2xl font-medium tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif] sm:text-3xl"
            >
              {if @settings["heading"] not in [nil, ""],
                do: @settings["heading"],
                else: "About the shop"}
            </h2>
          </div>
          <div>
            <p class="max-w-xl text-base leading-relaxed text-stone-700">
              {if @store.description,
                do: @store.description,
                else:
                  "Welcome to #{@store.name}. Take your time with the catalogue — each piece is numbered, priced, and ready to order."}
            </p>
            <a
              :if={Shared.wa_me(@store)}
              href={Shared.wa_me(@store)}
              target="_blank"
              rel="noopener noreferrer"
              class="mt-6 inline-flex min-h-[48px] items-center gap-2.5 border border-stone-900 px-6 py-3 text-sm font-semibold leading-none text-stone-900 hover:bg-stone-900 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 focus-visible:ring-offset-[#F7ECE7] motion-safe:transition-colors"
            >
              <svg class="h-4 w-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
              </svg>
              Chat on WhatsApp
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
