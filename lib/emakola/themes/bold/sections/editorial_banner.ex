defmodule Emakola.Themes.Bold.Sections.EditorialBanner do
  @moduledoc """
  Bold home editorial banner — full-width amber accent bar — extracted
  verbatim from bold/home.ex.

  Prints the merchant's banner text, or the store's own description, or
  nothing. "Curated for those who appreciate the art of well-made things."
  used to stand in for every store that had written neither.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Bold.Shared

  @impl true
  def key, do: "bold/editorial_banner"
  @impl true
  def label, do: "Editorial banner"

  @impl true
  def settings_schema do
    [%{key: "text", type: :text, label: "Banner text", default: ""}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :banner_text, banner_text(assigns[:settings] || %{}, assigns.store))

    ~H"""
    <section
      :if={@banner_text && Shared.section_enabled?(@theme, :editorial_banner)}
      class="bg-[#F59E0B]"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14 text-center">
        <p
          class="text-2xl sm:text-3xl lg:text-4xl font-bold italic text-[#0F172A] leading-snug max-w-3xl mx-auto"
          style="font-family: 'Outfit', sans-serif;"
        >
          {@banner_text}
        </p>
      </div>
    </section>
    """
  end

  defp banner_text(%{"text" => text}, _store) when text not in [nil, ""], do: text

  defp banner_text(_settings, store) do
    if Shared.present?(store.description), do: store.description, else: nil
  end
end
