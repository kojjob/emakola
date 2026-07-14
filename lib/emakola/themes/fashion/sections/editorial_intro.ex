defmodule Emakola.Themes.Fashion.Sections.EditorialIntro do
  @moduledoc """
  Fashion home editorial intro — the merchant's own words, or no section.

  The body used to read: "Each piece is sewn in small batches by tailors and
  artisans across Accra." The theme config went further and credited two
  workshops **that do not exist** — "the bold Ankara prints of the Mensah
  collective", "the heritage kente of the Kwame house". Invented names, on every
  Fashion storefront, attributing goods to makers who were never asked.

  The body is a claim about who made the clothes. Only the shop knows that, so
  only the shop writes it. Blank, the section does not render.
  """
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
      :if={@editorial_body && Shared.section_enabled?(@theme, :editorial_intro)}
      class="bg-[#FAF6EE] py-16 sm:py-24"
    >
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <p :if={@editorial_eyebrow} class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-4">
          {@editorial_eyebrow}
        </p>
        <h2 class="fashion-display text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-tight mb-6">
          {@editorial_title || @store.name}
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

  # "Curated drops, made by hand." was the fallback title — a claim about how the
  # clothes were made, on a theme any reseller could install. No fallback now.
  defp editorial_title(theme), do: get_in(theme, [:editorial_intro, :title])

  defp editorial_body(theme), do: get_in(theme, [:editorial_intro, :body])
end
