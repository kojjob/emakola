defmodule Emakola.Themes.Fashion.Sections.EditorialIntro do
  @moduledoc "Fashion home editorial intro — extracted verbatim from fashion/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Fashion.Shared

  @impl true
  def key, do: "fashion/editorial_intro"

  @impl true
  def label, do: "Editorial intro"

  @impl true
  def settings_schema do
    [
      %{key: "eyebrow", type: :string, label: "Eyebrow", default: ""},
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "body", type: :text, label: "Body", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    theme = assigns.theme

    assigns =
      assigns
      |> assign(:editorial_eyebrow, setting_or(assigns, "eyebrow", editorial_eyebrow(theme)))
      |> assign(:editorial_title, setting_or(assigns, "heading", editorial_title(theme)))
      |> assign(:editorial_body, setting_or(assigns, "body", editorial_body(theme)))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :editorial_intro)}
      class="bg-[#FAF6EE] py-16 sm:py-24"
    >
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-4">
          {@editorial_eyebrow}
        </p>
        <h2 class="fashion-display text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-tight mb-6">
          {@editorial_title}
        </h2>
        <p class="text-base sm:text-lg text-[#57534E] leading-relaxed">
          {@editorial_body}
        </p>
      </div>
    </section>
    """
  end

  # ── Helpers ──

  defp setting_or(assigns, key, fallback) do
    case assigns[:settings][key] do
      value when value not in [nil, ""] -> value
      _blank -> fallback
    end
  end

  defp editorial_eyebrow(theme),
    do: get_in(theme, [:editorial_intro, :eyebrow]) || "From the Editor"

  defp editorial_title(theme),
    do: get_in(theme, [:editorial_intro, :title]) || "Curated drops, made by hand."

  defp editorial_body(theme),
    do:
      get_in(theme, [:editorial_intro, :body]) ||
        "Each piece is sewn in small batches by tailors and artisans across Accra."
end
