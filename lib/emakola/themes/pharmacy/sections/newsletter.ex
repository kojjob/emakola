defmodule Emakola.Themes.Pharmacy.Sections.Newsletter do
  @moduledoc """
  Pharmacy home newsletter band — forest green, centred. Extracted verbatim
  from `pharmacy/home.ex`, including its form, which carries no `phx-submit`
  and is therefore not wired to the platform's newsletter handler. Wiring it
  up would change the storefront; it is reported, not fixed, by the
  sectionization.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/newsletter"

  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [
      %{key: "title", type: :string, label: "Heading", default: ""},
      %{key: "subtitle", type: :text, label: "Subheading", default: ""},
      %{key: "button_text", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={Shared.section_enabled?(@theme, :newsletter)} class="bg-[#14543E] py-14 sm:py-20">
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="pharmacy-heading text-3xl sm:text-4xl font-medium text-white mb-3">
          {if @settings["title"] not in [nil, ""],
            do: @settings["title"],
            else: newsletter_title(@theme)}
        </h2>
        <p class="text-sm text-[#F9F6F0]/80 mb-8">
          {if @settings["subtitle"] not in [nil, ""],
            do: @settings["subtitle"],
            else: newsletter_subtitle(@theme)}
        </p>
        <form class="flex flex-col sm:flex-row gap-3 max-w-lg mx-auto">
          <label for="pharmacy-newsletter-email" class="sr-only">Email</label>
          <input
            type="email"
            id="pharmacy-newsletter-email"
            placeholder="Enter your email"
            class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-[#F9F6F0]/60 focus:outline-none focus:ring-2 focus:ring-[#A7E5C5] text-sm"
          />
          <button
            type="submit"
            class="px-7 py-3.5 rounded-full bg-[#A7E5C5] text-[#14543E] text-sm font-semibold hover:bg-white transition-colors min-h-[48px]"
          >
            {if @settings["button_text"] not in [nil, ""],
              do: @settings["button_text"],
              else: newsletter_button(@theme)}
          </button>
        </form>
      </div>
    </section>
    """
  end

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "Stay healthy, stay informed"

  defp newsletter_subtitle(theme),
    do:
      get_in(theme, [:newsletter, :subtitle]) ||
        "Health tips, new launches, and offers from our pharmacists."

  defp newsletter_button(theme),
    do: get_in(theme, [:newsletter, :button_text]) || "Subscribe"
end
