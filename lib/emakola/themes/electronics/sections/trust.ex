defmodule Emakola.Themes.Electronics.Sections.Trust do
  @moduledoc """
  Electronics home trust statement -- extracted verbatim from
  electronics/home.ex: a centred two-line statement on cream.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers

  @impl true
  def key, do: "electronics/trust"
  @impl true
  def label, do: "Trust statement"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:heading, setting(assigns[:settings], "heading", trust_title(assigns.theme)))
      |> assign(
        :subheading,
        setting(assigns[:settings], "subheading", trust_subtitle(assigns.theme))
      )

    ~H"""
    <%!-- TRUST STATEMENT --%>
    <section :if={section_enabled?(@theme, :trust)} class="bg-[#F5EFE5] py-14 sm:py-20">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="electronics-heading text-2xl sm:text-3xl lg:text-4xl font-bold text-[#134E4A] leading-tight mb-3">
          {@heading}
        </h2>
        <p class="text-base text-[#4B5563] leading-relaxed">
          {@subheading}
        </p>
      </div>
    </section>
    """
  end

  defp trust_title(theme), do: get_in(theme, [:trust, :title]) || "Why thousands trust us"

  defp trust_subtitle(theme),
    do:
      get_in(theme, [:trust, :subtitle]) ||
        "Genuine products. 1-year warranty. Free shipping."
end
