defmodule Emakola.Themes.Electronics.Sections.CtaBand do
  @moduledoc """
  Electronics home dark CTA band with the star pattern -- extracted verbatim
  from electronics/home.ex.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "electronics/cta_band"
  @impl true
  def label, do: "CTA band"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""},
      %{key: "button_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    settings = assigns[:settings]

    assigns =
      assigns
      |> assign(:heading, setting(settings, "heading", cta_band_title(assigns.theme)))
      |> assign(:subheading, setting(settings, "subheading", cta_band_subtitle(assigns.theme)))
      |> assign(
        :button_label,
        setting(settings, "button_label", cta_band_button(assigns.theme))
      )

    ~H"""
    <%!-- DARK CTA BAND with star pattern --%>
    <section
      :if={section_enabled?(@theme, :cta_band)}
      class="bg-[#134E4A] py-14 sm:py-20 relative overflow-hidden"
    >
      <%!-- Star pattern background --%>
      <div class="absolute inset-0 opacity-10">
        <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern
              id="electronics-stars"
              x="0"
              y="0"
              width="80"
              height="80"
              patternUnits="userSpaceOnUse"
            >
              <path
                d="M40 10l4 12 12 1-9 8 3 12-10-7-10 7 3-12-9-8 12-1z"
                fill="white"
                fill-opacity="0.6"
              />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#electronics-stars)" />
        </svg>
      </div>
      <div class="relative max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center text-white">
        <h2 class="electronics-heading text-3xl sm:text-4xl lg:text-5xl font-extrabold leading-tight mb-3">
          {@heading}
        </h2>
        <p class="text-base text-white/80 mb-7">{@subheading}</p>
        <a
          href={store_path(@store.slug, "/products")}
          class="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-white text-[#134E4A] text-sm font-bold hover:bg-[#F5EFE5] transition-colors min-h-[48px]"
        >
          {@button_label}
          <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
        </a>
      </div>
    </section>
    """
  end

  defp cta_band_title(theme),
    do: get_in(theme, [:cta_band, :title]) || "Explore our latest collection"

  defp cta_band_subtitle(theme),
    do: get_in(theme, [:cta_band, :subtitle]) || "of electronics"

  defp cta_band_button(theme),
    do: get_in(theme, [:cta_band, :button_text]) || "Shop the Collection"
end
