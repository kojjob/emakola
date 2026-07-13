defmodule Emakola.Themes.Vibrant.Sections.TrustBadges do
  @moduledoc """
  Vibrant trust badge strip — the chip row that sits directly under the hero.

  Extracted verbatim from the pre-section home, including its gate: this strip
  has always been shown or hidden by the *hero* section toggle, never one of
  its own. Keeping that quirk keeps the page identical for every store that
  toggled sections through the old theme customiser.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [trust_badges_strip: 1]

  alias Emakola.Themes.Vibrant.Shared

  @impl true
  def key, do: "vibrant/trust_badges"

  @impl true
  def label, do: "Trust badges"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:enabled, Shared.section_enabled?(assigns.theme, :hero))
      |> assign(:badges, trust_badges_for(assigns.store))

    ~H"""
    <section
      :if={@enabled}
      class="bg-white border-y border-[#FDE68A]/60"
      aria-label="Why shop with us"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <.trust_badges_strip badges={@badges} class="justify-center sm:justify-start" />
      </div>
    </section>
    """
  end

  defp trust_badges_for(_store) do
    [
      %{icon: "public", label: "Locally crafted", variant: :provenance},
      %{icon: "verified", label: "Authenticated", variant: :default},
      %{icon: "payments", label: "Mobile Money", variant: :default}
    ]
  end
end
