defmodule Emakola.Themes.HomeLiving.Sections.Newsletter do
  @moduledoc """
  Home Living newsletter band.

  The form fires `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription`. It was inert before: no
  `phx-submit`, no action, so the submit button did nothing at all. Still gated
  by the legacy `@theme.sections.newsletter` toggle underneath the section
  editor's own `enabled` flag, and shown only once the stall is full enough
  to have news: four or more products (`Emakola.Themes.Layout`).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.HomeLiving.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "home_living/newsletter"
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
    assigns =
      assigns
      |> assign(:layout, Layout.of(assigns))
      |> assign(
        :heading,
        present(assigns.settings["heading"]) || get_in(assigns.theme, [:newsletter, :title]) ||
          "New pieces, in your inbox"
      )
      # "Restocks, seasonal releases, and home inspiration — once a month"
      # promised a cadence and content on the merchant's behalf.
      |> assign(
        :subheading,
        present(assigns.settings["subheading"]) ||
          present(get_in(assigns.theme, [:newsletter, :subtitle])) ||
          "New products and updates from #{assigns.store.name}, straight to your inbox."
      )
      |> assign(
        :cta_label,
        present(assigns.settings["cta_label"]) ||
          get_in(assigns.theme, [:newsletter, :button_text]) || "Subscribe"
      )

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :newsletter) && @layout.show_newsletter?}
      class="bg-[#1F2937] py-14 sm:py-20"
    >
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="home-living-heading text-3xl sm:text-4xl font-bold text-white mb-3">
          {@heading}
        </h2>
        <p class="text-sm text-white/70 mb-7">{@subheading}</p>
        <form
          class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
          phx-submit="subscribe_newsletter"
        >
          <label for="home-living-newsletter-email" class="sr-only">Email</label>
          <input
            type="email"
            id="home-living-newsletter-email"
            name="email"
            required
            placeholder="Enter your email"
            class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-white/50 focus:outline-none focus:ring-2 focus:ring-[#84CC16] text-sm"
          />
          <button
            type="submit"
            class="px-7 py-3.5 rounded-full bg-[#84CC16] text-[#1F2937] text-sm font-bold hover:bg-white transition-colors min-h-[48px]"
          >
            {@cta_label}
          </button>
        </form>
      </div>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
