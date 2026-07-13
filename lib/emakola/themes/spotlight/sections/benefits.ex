defmodule Emakola.Themes.Spotlight.Sections.Benefits do
  @moduledoc """
  Spotlight home benefits strip — extracted verbatim from spotlight/home.ex.

  The cards come from the theme's `trust.items` (icon, title, description);
  only the heading is exposed as a section setting, because that is the only
  scalar the markup reads. Still gated by the legacy `@theme.sections.why_us`
  toggle underneath the section editor's own `enabled` flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

  @impl true
  def key, do: "spotlight/benefits"
  @impl true
  def label, do: "Benefits"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :trust, get_in(assigns.theme, [:trust]) || %{})

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :why_us)}
      id="benefits"
      phx-hook="ScrollReveal"
      class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16"
    >
      <h2 class="spot-heading text-3xl font-bold text-center mb-10">
        {if @settings["heading"] not in [nil, ""],
          do: @settings["heading"],
          else: Map.get(@trust, :title, "What makes it different")}
      </h2>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-6">
        <div
          :for={item <- Map.get(@trust, :items, [])}
          data-reveal
          class="rounded-2xl bg-white border border-[#ECE7DE] p-6 text-center"
        >
          <span class="material-symbols-outlined text-[var(--theme-accent,#7C3AED)] text-3xl">
            {Map.get(item, :icon, "star")}
          </span>
          <h3 class="spot-heading text-base font-semibold mt-3">{item.title}</h3>
          <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{item.description}</p>
        </div>
      </div>
    </section>
    """
  end
end
