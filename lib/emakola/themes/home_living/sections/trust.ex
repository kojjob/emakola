defmodule Emakola.Themes.HomeLiving.Sections.Trust do
  @moduledoc """
  Home Living trust strip — extracted verbatim from home_living/home.ex.

  The items come from `@theme.trust.items` (icon/label/subtitle maps), which
  no flat setting type can express, so the section declares no settings and
  keeps reading the theme config. Still gated by the legacy
  `@theme.sections.trust` toggle underneath the section editor's own `enabled`
  flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.HomeLiving.Shared

  @impl true
  def key, do: "home_living/trust"
  @impl true
  def label, do: "Trust strip"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :items, trust_items(assigns.theme))

    ~H"""
    <section :if={Shared.section_enabled?(@theme, :trust)} class="bg-white py-12 sm:py-16">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <div :for={item <- @items} class="flex items-center gap-4">
            <div class="w-14 h-14 rounded-2xl bg-[#84CC16]/15 flex items-center justify-center flex-shrink-0">
              <span class="material-symbols-outlined text-[#1F2937]" style="font-size: 26px;">
                {item.icon}
              </span>
            </div>
            <div>
              <p class="text-base font-semibold text-[#1F2937] mb-0.5">{item.label}</p>
              <p class="text-xs text-[#4B5563]">{item.subtitle}</p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp trust_items(theme) do
    case get_in(theme, [:trust, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_trust()
    end
  end

  defp default_trust do
    [
      %{icon: "category", label: "Quality materials", subtitle: "Solid wood, natural fibres"},
      %{icon: "local_shipping", label: "Ships in 5 days", subtitle: "Across Ghana"},
      %{icon: "swap_horiz", label: "30-day returns", subtitle: "No questions asked"}
    ]
  end
end
