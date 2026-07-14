defmodule Emakola.Themes.Beauty.Sections.WhyUs do
  @moduledoc """
  Beauty "why us" block — three feature cards on the dark walnut band.

  The cards are the merchant's own (`why_us.items`, icon / title / description).
  There is no fallback trio, and a store that has written none gets no block.

  The trio that used to sit here claimed "Dermatologist-tested formulas with
  botanical actives", "Recyclable glass and biodegradable inserts", and "West
  African shea, cocoa, and baobab" — a clinical testing claim, a packaging claim
  and a sourcing claim, published by every store that installed the theme. Note
  that "Dermatologist-tested" appeared ONLY in this fallback, not in the theme
  config it shadowed: emptying the config alone would not have removed it.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Item

  @impl true
  def key, do: "beauty/why_us"

  @impl true
  def label, do: "Why us"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :items, why_us_items(assigns.theme))

    ~H"""
    <section
      :if={@items != [] && section_enabled?(@theme, :why_us)}
      class="bg-[#6B4423] py-16 sm:py-24 text-[#FAF6EE]"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-12">
          <h2 class="beauty-heading text-4xl sm:text-5xl font-semibold mb-3">
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: why_us_title(@theme)}
          </h2>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-5 sm:gap-6">
          <div
            :for={item <- @items}
            class="bg-[#5A381D] rounded-2xl p-6 sm:p-8 hover:bg-[#4A2D14] transition-colors"
          >
            <div class="w-14 h-14 rounded-full bg-[#C9925E] flex items-center justify-center mb-5">
              <span class="material-symbols-outlined text-[#3D2F25]" style="font-size: 26px;">
                {Item.field(item, :icon, "spa")}
              </span>
            </div>
            <h3 class="beauty-heading text-xl sm:text-2xl font-semibold mb-3">
              {Item.field(item, :title)}
            </h3>
            <p class="text-sm text-[#FAF6EE]/75 leading-relaxed">
              {Item.field(item, :description)}
            </p>
          </div>
        </div>
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

  defp why_us_title(theme),
    do: get_in(theme, [:why_us, :title]) || "Why your skin deserves the best"

  defp why_us_items(theme) do
    case get_in(theme, [:why_us, :items]) do
      items when is_list(items) -> Enum.filter(items, &Item.has?(&1, :title))
      _ -> []
    end
  end
end
