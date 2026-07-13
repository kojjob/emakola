defmodule Emakola.Themes.Beauty.Sections.ClosingCta do
  @moduledoc """
  Beauty closing call-to-action — the deepest walnut band, centred, sending
  the shopper to the catalogue.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "beauty/closing_cta"

  @impl true
  def label, do: "Closing CTA"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :text, label: "Subheading", default: ""},
      %{key: "button_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={section_enabled?(@theme, :closing_cta)}
      class="bg-[#3D2F25] py-16 sm:py-24 text-center"
    >
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <h2 class="beauty-heading text-4xl sm:text-5xl lg:text-6xl font-semibold text-[#FAF6EE] mb-5 leading-tight">
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: closing_title(@theme)}
        </h2>
        <p class="text-base text-[#FAF6EE]/75 mb-8 max-w-xl mx-auto">
          {if @settings["subheading"] not in [nil, ""],
            do: @settings["subheading"],
            else: closing_subtitle(@theme)}
        </p>
        <a
          href={store_path(@store.slug, "/products")}
          class="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-[var(--theme-accent,#C9925E)] text-[#3D2F25] text-sm font-bold hover:bg-[#FAF6EE] transition-colors min-h-[48px]"
        >
          {if @settings["button_label"] not in [nil, ""],
            do: @settings["button_label"],
            else: closing_button(@theme)}
          <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
        </a>
      </div>
    </section>
    """
  end

  defp section_enabled?(theme, name) do
    case get_in(theme, [:sections, name]) do
      false -> false
      _ -> true
    end
  end

  defp closing_title(theme),
    do: get_in(theme, [:closing_cta, :title]) || "Ready for flawless skin?"

  defp closing_subtitle(theme),
    do: get_in(theme, [:closing_cta, :subtitle]) || "Shop the collection."

  defp closing_button(theme),
    do: get_in(theme, [:closing_cta, :button_text]) || "Shop Now"
end
