defmodule Emakola.Themes.Atelier.Sections.Newsletter do
  @moduledoc "Atelier home newsletter section -- extracted verbatim from atelier/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Atelier.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "atelier/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    newsletter_config = get_in(assigns.theme, [:newsletter]) || %{}

    nl_heading =
      Map.get(newsletter_config, :heading, "Stay Updated.")

    nl_description =
      Map.get(
        newsletter_config,
        :description,
        "Be the first to discover new collections, exclusive offers, and updates from our store."
      )

    nl_button_text =
      Map.get(newsletter_config, :button_text, "Join Now")

    nl_placeholder =
      Map.get(newsletter_config, :placeholder, "Enter your email")

    nl_disclaimer =
      Map.get(newsletter_config, :disclaimer, "No spam. Unsubscribe anytime.")

    assigns =
      assigns
      |> assign(:nl_heading, nl_heading)
      |> assign(:nl_description, nl_description)
      |> assign(:nl_button_text, nl_button_text)
      |> assign(:nl_placeholder, nl_placeholder)
      |> assign(:nl_disclaimer, nl_disclaimer)
      |> assign(:layout, Layout.of(assigns))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :newsletter) and @layout.show_newsletter?}
      class="bg-white"
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div class="max-w-xl mx-auto text-center">
          <h2 class="text-3xl sm:text-4xl lg:text-5xl font-black text-gray-900 mb-4">
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: @nl_heading}
          </h2>
          <p class="text-gray-600 text-base sm:text-lg leading-relaxed mb-8">
            {@nl_description}
          </p>
          <form class="flex flex-col sm:flex-row gap-3 mb-4" phx-submit="subscribe_newsletter">
            <label for="newsletter-email" class="sr-only">Email address</label>
            <input
              id="newsletter-email"
              type="email"
              name="email"
              placeholder={@nl_placeholder}
              required
              class="flex-1 px-5 py-3.5 bg-gray-100 rounded-lg text-sm text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 transition-shadow duration-200 border-0 min-h-[48px]"
              style="--tw-ring-color: var(--theme-primary);"
            />
            <button
              type="submit"
              class="cursor-pointer px-8 py-3.5 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-all duration-200 hover:opacity-90 whitespace-nowrap min-h-[48px]"
              style="background: var(--theme-accent, #166534);"
            >
              {@nl_button_text}
            </button>
          </form>
          <p class="text-xs text-gray-400">
            {@nl_disclaimer}
          </p>
        </div>
      </div>
    </section>
    """
  end
end
