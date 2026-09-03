defmodule Emakola.Themes.Market.Home do
  @moduledoc """
  Market theme — home page chrome.

  Renders theme chrome — skip link, Market's own banner nav (store
  identity, categories, search, live cart count), the store's effective
  home-section layout via `SectionRenderer`, Market's own footer, and the
  mobile bottom tab bar. Section markup lives in
  `Emakola.Themes.Market.Sections.*`; each section is a top-level sibling
  owning its own horizontal padding.
  """
  use Phoenix.Component

  alias Emakola.Themes.Market.{Layout, Shared}
  alias Emakola.Themes.SectionRenderer

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Market)
      |> assign(:layout, Layout.plan(assigns))

    ~H"""
    <div>
      <Shared.theme_styles theme={@theme} />
      <a
        href="#market-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-stone-900 focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>
      <Shared.market_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />
      <div id="market-content">
        {SectionRenderer.home(assigns)}
      </div>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <a
      :if={whatsapp_digits(@store)}
      id="market-whatsapp-fab"
      href={"https://wa.me/#{whatsapp_digits(@store)}"}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={"Chat with #{@store.name} on WhatsApp"}
      class="fixed bottom-[4.5rem] right-4 z-40 flex h-14 w-14 items-center justify-center rounded-full bg-whatsapp text-white shadow-lg shadow-whatsapp/40 hover:bg-whatsapp-dark focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors sm:bottom-6"
    >
      <svg class="h-6 w-6" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
        <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
      </svg>
    </a>
    <Shared.market_bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} />
    """
  end

  defp whatsapp_digits(store) do
    case Map.get(store, :whatsapp_number) do
      number when is_binary(number) ->
        digits = String.replace(number, ~r/\D/, "")
        if digits == "", do: nil, else: digits

      _ ->
        nil
    end
  end
end
