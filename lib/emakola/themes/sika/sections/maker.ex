defmodule Emakola.Themes.Sika.Sections.Maker do
  @moduledoc """
  Sika home maker's-mark section — the stamp behind the pieces.

  The store's initial in a large maker's-mark stamp, the merchant's own
  story (with a promise-free fallback), and a WhatsApp enquiry when the
  store has a number — how gold is actually bought in Ghana: you speak
  with the maker first.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Sika.Shared

  @impl true
  def key, do: "sika/maker"
  @impl true
  def label, do: "The maker"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "The maker's mark"}]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:heading, Shared.present(assigns.settings["heading"]) || "The maker's mark")
      |> assign(:whatsapp, whatsapp_href(assigns.store))

    ~H"""
    <section class="px-4 py-10 sm:px-6 sm:py-14 lg:px-8" aria-labelledby="sika-maker-heading">
      <div class="mx-auto max-w-2xl text-center">
        <Shared.makers_mark name={@store.name} class="mx-auto h-16 w-16 text-2xl" />
        <h2
          id="sika-maker-heading"
          class="mt-5 text-2xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]"
        >
          {@heading}
        </h2>
        <Shared.caught_light class="mx-auto mt-4 w-16" />
        <p class="mt-5 text-sm leading-relaxed text-[#6E675C] sm:text-base">
          {if @store.description,
            do: @store.description,
            else: "Welcome to #{@store.name} — a small collection, chosen with care."}
        </p>
        <a
          :if={@whatsapp}
          href={@whatsapp}
          target="_blank"
          rel="noopener noreferrer"
          class="mt-7 inline-flex items-center gap-2.5 border border-[#211D16] px-7 py-3.5 text-[0.75rem] font-semibold uppercase tracking-[0.2em] text-[#211D16] hover:bg-[#211D16] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-colors"
        >
          <svg class="h-4 w-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
            <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
          </svg>
          Ask about a piece
        </a>
      </div>
    </section>
    """
  end

  defp whatsapp_href(store) do
    case Map.get(store, :whatsapp_number) do
      number when is_binary(number) and number != "" -> "https://wa.me/#{number}"
      _ -> nil
    end
  end
end
