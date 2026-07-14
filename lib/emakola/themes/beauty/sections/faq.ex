defmodule Emakola.Themes.Beauty.Sections.Faq do
  @moduledoc """
  Beauty FAQ accordion — native `<details>` disclosures, no JavaScript.

  Questions come from the theme's `faq.items` config; a store with none
  renders the heading and an empty list, exactly as it does today.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Item

  @impl true
  def key, do: "beauty/faq"

  @impl true
  def label, do: "FAQ"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={section_enabled?(@theme, :faq)} class="bg-[#F5EFE5] pb-16 sm:pb-24">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-10">
          <h2 class="beauty-heading text-3xl sm:text-4xl font-semibold text-[#3D2F25] mb-2">
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: faq_title(@theme)}
          </h2>
          <p class="text-sm text-[#6B4423]/70">
            {if @settings["subheading"] not in [nil, ""],
              do: @settings["subheading"],
              else: faq_subtitle(@theme)}
          </p>
        </div>
        <div class="space-y-3">
          <details :for={item <- faq_items(@theme)} class="beauty-card group">
            <summary class="flex items-center justify-between p-5 cursor-pointer list-none">
              <span class="text-base font-semibold text-[#3D2F25] pr-4">
                {Item.field(item, :question)}
              </span>
              <span
                class="material-symbols-outlined text-[#C9925E] transition-transform group-open:rotate-45"
                style="font-size: 22px;"
              >
                add
              </span>
            </summary>
            <div class="px-5 pb-5 -mt-1">
              <p class="text-sm text-[#3D2F25]/80 leading-relaxed">{Item.field(item, :answer)}</p>
            </div>
          </details>
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

  defp faq_title(theme), do: get_in(theme, [:faq, :title]) || "Frequently Asked Questions"

  defp faq_subtitle(theme),
    do: get_in(theme, [:faq, :subtitle]) || "Got questions? We've got answers."

  defp faq_items(theme) do
    case get_in(theme, [:faq, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> []
    end
  end
end
