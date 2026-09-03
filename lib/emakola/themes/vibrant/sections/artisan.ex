defmodule Emakola.Themes.Vibrant.Sections.Artisan do
  @moduledoc """
  Vibrant artisan signature — the maker card, gated by the theme's `about`
  toggle and shown only when the merchant has written a description
  (`Emakola.Themes.Layout`): the card is the merchant's own story, and there
  is no story to tell for them.

  Carries the second kente pattern divider, outside the gate, for the same
  reason the featured card does: it renders today whether or not the card does.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents,
    only: [artisan_signature_card: 1, pattern_divider: 1]

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Vibrant.Shared

  @impl true
  def key, do: "vibrant/artisan"

  @impl true
  def label, do: "Artisan signature"

  @impl true
  def settings_schema do
    [%{key: "headline", type: :string, label: "Eyebrow", default: "Meet the Maker"}]
  end

  @impl true
  def render(assigns) do
    settings = assigns[:settings] || %{}

    assigns =
      assigns
      |> assign(
        :enabled,
        Shared.section_enabled?(assigns.theme, :about) and Layout.of(assigns).show_about?
      )
      |> assign(:headline, present(settings["headline"]) || "Meet the Maker")

    ~H"""
    <.pattern_divider variant={:kente} class="bg-[#FFFBEB]" />

    <section :if={@enabled} class="py-10 sm:py-14 bg-[#FFFBEB]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <.artisan_signature_card store={@store} headline={@headline} />
      </div>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
