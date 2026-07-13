defmodule Emakola.Themes.Spotlight.Sections.Testimonials do
  @moduledoc """
  Spotlight home testimonials — extracted verbatim from spotlight/home.ex.

  The quotes come from the theme's `testimonials.items` (theme-config
  content the merchant owns); this module invents none and adds none. Only
  the heading is exposed as a setting, because it is the only scalar the
  markup reads. Still gated by the legacy `@theme.sections.testimonials`
  toggle underneath the section editor's own `enabled` flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

  @impl true
  def key, do: "spotlight/testimonials"
  @impl true
  def label, do: "Testimonials"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :testimonials, get_in(assigns.theme, [:testimonials]) || %{})

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :testimonials)}
      phx-hook="ScrollReveal"
      id="testimonials"
      class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16"
    >
      <h2 class="spot-heading text-3xl font-bold text-center mb-10">
        {if @settings["heading"] not in [nil, ""],
          do: @settings["heading"],
          else: Map.get(@testimonials, :title, "Loved by everyday people")}
      </h2>
      <div class="grid md:grid-cols-3 gap-6">
        <figure
          :for={t <- Map.get(@testimonials, :items, [])}
          data-reveal
          class="rounded-2xl bg-white border border-[#ECE7DE] p-6"
        >
          <div class="text-[var(--theme-accent,#7C3AED)]">★★★★★</div>
          <blockquote class="text-sm text-[#16130F] mt-3 leading-relaxed">"{t.quote}"</blockquote>
          <figcaption class="text-xs text-[#6B675F] mt-4 font-semibold">
            {t.name}<span :if={Map.get(t, :location)} class="font-normal"> · {t.location}</span>
          </figcaption>
        </figure>
      </div>
    </section>
    """
  end
end
