defmodule Emakola.Themes.Pharmacy.Sections.Stats do
  @moduledoc """
  Pharmacy home stats strip — cream band of merchant-supplied numbers.
  Extracted verbatim from `pharmacy/home.ex`.

  Renders only when the merchant has supplied stat items in the theme config
  (`stats.items`), exactly as before: the platform invents no numbers.

  Because it renders *only* on merchant items, and merchant items arrive
  string-keyed from jsonb, the old `stat.icon` dot access raised a `KeyError` on
  every store that used this section and never on a default — the reason it went
  unseen. Fields go through `Emakola.Themes.Item`, which reads either key shape.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Item
  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/stats"

  @impl true
  def label, do: "Stats"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subtitle", type: :text, label: "Subheading", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :stats_items, stats_items(assigns.theme))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :stats) && @stats_items != []}
      class="bg-[#F9F6F0] py-14 sm:py-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid lg:grid-cols-2 gap-10 mb-12 items-end">
          <h2 class="pharmacy-heading text-3xl sm:text-4xl lg:text-5xl font-medium text-[#14543E] leading-tight">
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: stats_heading(@theme)}
          </h2>
          <p class="text-base text-[#4B5563] leading-relaxed">
            {if @settings["subtitle"] not in [nil, ""],
              do: @settings["subtitle"],
              else: stats_subtitle(@theme)}
          </p>
        </div>

        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <div :for={stat <- @stats_items} class="pharmacy-card p-6 sm:p-7 flex items-center gap-4">
            <div class="w-12 h-12 rounded-full bg-[#A7E5C5] flex items-center justify-center flex-shrink-0">
              <span class="material-symbols-outlined text-[#14543E]" style="font-size: 22px;">
                {Item.field(stat, :icon, "insights")}
              </span>
            </div>
            <div>
              <p class="pharmacy-heading text-2xl sm:text-3xl font-semibold text-[#14543E]">
                {Item.field(stat, :value)}
              </p>
              <p class="text-xs text-[#4B5563] uppercase tracking-wider mt-0.5">
                {Item.field(stat, :label)}
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp stats_heading(theme), do: get_in(theme, [:stats, :heading]) || "Your Trusted Healthcare"

  defp stats_subtitle(theme),
    do:
      get_in(theme, [:stats, :subtitle]) ||
        "We believe in lasting relationships, not just transactions."

  # Stats render only when the merchant supplies real numbers via the theme
  # `stats` config — no invented defaults.
  defp stats_items(theme) do
    case get_in(theme, [:stats, :items]) do
      items when is_list(items) -> items
      _ -> []
    end
  end
end
