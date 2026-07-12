defmodule Emakola.Themes.Ntoma.Sections.Wordmark do
  @moduledoc """
  Ntoma's signature: the band carrying the store's own name at display scale.

  A small Accra tailor gets their name set like a fashion house — that is
  the emotional payload of this theme, and it costs zero image bytes. The
  band is set on the theme's paper and edged with the woven selvedge strip;
  the gold lives in the selvedge, not in a full-bleed slab, so the buy button
  stays the loudest thing on the page. The merchant may add a tagline; the
  quiet link always points at the server-generated products path.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Ntoma.Shared

  @impl true
  def key, do: "ntoma/wordmark"
  @impl true
  def label, do: "Wordmark band"

  @impl true
  def settings_schema do
    [
      %{key: "tagline", type: :string, label: "Tagline", default: ""},
      %{key: "cta_label", type: :string, label: "Link label", default: "Shop all"}
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:tagline, present(assigns.settings["tagline"]))
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Shop all")

    ~H"""
    <section class="overflow-hidden bg-[#FFFBF2]" aria-labelledby="ntoma-wordmark-heading">
      <%!-- The band used to be a full-bleed slab of gold, which shouted louder
      than any buy button on the page. The gold survives where it means
      something — the woven selvedge that edges the cloth — and the name itself
      now carries the band, set on the theme's own paper. --%>
      <Shared.woven_strip class="h-1.5" />
      <div class="mx-auto max-w-[1280px] px-4 py-12 sm:px-6 sm:py-16 lg:px-8">
        <h2
          id="ntoma-wordmark-heading"
          class="break-words text-[clamp(2.5rem,12vw,9rem)] font-semibold uppercase leading-[0.9] tracking-[-0.01em] text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)]"
        >
          {@store.name}
        </h2>
        <div class="mt-7 flex flex-wrap items-end justify-between gap-4">
          <p
            :if={@tagline}
            id="ntoma-wordmark-tagline"
            class="max-w-md text-sm text-[#2B1708]/80 sm:text-base"
          >
            {@tagline}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="group inline-flex min-h-[44px] items-center gap-2 border-b-2 border-[#2B1708] text-sm font-bold uppercase tracking-[0.16em] text-[#2B1708] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 focus-visible:ring-offset-[#FFFBF2]"
          >
            {@cta_label}
            <svg
              class="h-4 w-4 motion-safe:transition-transform motion-safe:group-hover:translate-x-1"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
              />
            </svg>
          </a>
        </div>
      </div>
      <Shared.woven_strip class="h-1.5" />
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
