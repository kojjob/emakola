defmodule Emakola.Themes.Beauty.Sections.WhyUs do
  @moduledoc """
  Beauty "why us" block — three feature cards on the dark walnut band.

  The cards come from the theme's `why_us.items` config (icon / title /
  description), falling back to the theme's built-in trio. The heading is
  editable per section; blank falls back to the theme's `why_us.title`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

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
    ~H"""
    <section
      :if={section_enabled?(@theme, :why_us)}
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
            :for={item <- why_us_items(@theme)}
            class="bg-[#5A381D] rounded-2xl p-6 sm:p-8 hover:bg-[#4A2D14] transition-colors"
          >
            <div class="w-14 h-14 rounded-full bg-[#C9925E] flex items-center justify-center mb-5">
              <span class="material-symbols-outlined text-[#3D2F25]" style="font-size: 26px;">
                {item.icon}
              </span>
            </div>
            <h3 class="beauty-heading text-xl sm:text-2xl font-semibold mb-3">
              {item.title}
            </h3>
            <p class="text-sm text-[#FAF6EE]/75 leading-relaxed">
              {item.description}
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
      items when is_list(items) and items != [] -> items
      _ -> default_why_us()
    end
  end

  defp default_why_us do
    [
      %{
        icon: "spa",
        title: "Proven Effectiveness",
        description: "Dermatologist-tested formulas with botanical actives."
      },
      %{
        icon: "compost",
        title: "Eco-friendly Packaging",
        description: "Recyclable glass and biodegradable inserts."
      },
      %{
        icon: "local_florist",
        title: "Botanical Skin Love",
        description: "West African shea, cocoa, and baobab — kind to melanin."
      }
    ]
  end
end
