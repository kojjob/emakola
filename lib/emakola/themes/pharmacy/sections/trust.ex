defmodule Emakola.Themes.Pharmacy.Sections.Trust do
  @moduledoc """
  Pharmacy home trust strip — Licensed / Genuine / Discreet, on white.
  Extracted verbatim from `pharmacy/home.ex`.

  The licensing and sourcing statements are regulated health copy: they are
  the merchant's own (`@theme.trust`), and the fallback items are moved here
  word for word.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/trust"

  @impl true
  def label, do: "Trust"

  @impl true
  def settings_schema do
    [
      %{key: "title", type: :string, label: "Heading", default: ""},
      %{key: "subtitle", type: :text, label: "Subheading", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={Shared.section_enabled?(@theme, :trust)} class="bg-white py-14 sm:py-20">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-10">
          <h2 class="pharmacy-heading text-3xl sm:text-4xl font-medium text-[#14543E]">
            {if @settings["title"] not in [nil, ""],
              do: @settings["title"],
              else: trust_title(@theme)}
          </h2>
          <p class="text-sm text-[#4B5563] mt-3 max-w-xl mx-auto">
            {if @settings["subtitle"] not in [nil, ""],
              do: @settings["subtitle"],
              else: trust_subtitle(@theme)}
          </p>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <div
            :for={item <- trust_items(@theme)}
            class="flex flex-col items-center text-center px-6 py-8"
          >
            <div class="w-16 h-16 rounded-full bg-[#A7E5C5] flex items-center justify-center mb-5">
              <span class="material-symbols-outlined text-[#14543E]" style="font-size: 30px;">
                {item.icon}
              </span>
            </div>
            <p class="text-base font-semibold text-[#14543E] mb-1">{item.label}</p>
            <p class="text-sm text-[#4B5563]">{item.subtitle}</p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp trust_title(theme), do: get_in(theme, [:trust, :title]) || "Licensed & Trusted"

  defp trust_subtitle(theme),
    do:
      get_in(theme, [:trust, :subtitle]) ||
        "Verified pharmacy. Genuine medicines. Discreet delivery."

  defp trust_items(theme) do
    case get_in(theme, [:trust, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_trust_items()
    end
  end

  defp default_trust_items do
    [
      %{icon: "verified_user", label: "Licensed pharmacy", subtitle: "Professional care"},
      %{icon: "local_pharmacy", label: "Genuine medicines", subtitle: "Trusted brands only"},
      %{icon: "local_shipping", label: "Discreet delivery", subtitle: "Across Ghana, fast"}
    ]
  end
end
