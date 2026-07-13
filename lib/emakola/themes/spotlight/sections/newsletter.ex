defmodule Emakola.Themes.Spotlight.Sections.Newsletter do
  @moduledoc """
  Spotlight home newsletter band — extracted verbatim from
  spotlight/home.ex.

  Note the form is inert today: it carries no `phx-submit` and its button is
  a `type="button"`, exactly as before the retrofit. Wiring it to the
  platform's `subscribe_newsletter` handler would change the storefront, so
  it is left alone here and tracked separately. Still gated by the legacy
  `@theme.sections.newsletter` toggle underneath the section editor's own
  `enabled` flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

  @impl true
  def key, do: "spotlight/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :text, label: "Subheading", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :newsletter)}
      class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 text-center"
    >
      <h2 class="spot-heading text-2xl font-bold">
        {if @settings["heading"] not in [nil, ""],
          do: @settings["heading"],
          else: get_in(@theme, [:newsletter, :title]) || "Stay in the loop"}
      </h2>
      <p class="text-sm text-[#6B675F] mt-2">
        {if @settings["subheading"] not in [nil, ""],
          do: @settings["subheading"],
          else: get_in(@theme, [:newsletter, :subtitle])}
      </p>
      <form class="flex max-w-md mx-auto mt-6 gap-2">
        <input
          type="email"
          placeholder="you@email.com"
          class="flex-1 px-4 py-3 rounded-full border border-[#ECE7DE] text-sm focus:outline-none focus:border-[var(--theme-accent,#7C3AED)]"
        />
        <button type="button" class="rounded-full spot-cta px-6 py-3 text-sm font-semibold">
          {if @settings["cta_label"] not in [nil, ""],
            do: @settings["cta_label"],
            else: get_in(@theme, [:newsletter, :button_text]) || "Subscribe"}
        </button>
      </form>
    </section>
    """
  end
end
