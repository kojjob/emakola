defmodule Emakola.Themes.Electronics.Sections.Newsletter do
  @moduledoc """
  Electronics home newsletter band.

  The form fires `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription`. It previously posted nowhere and
  fired no LiveView event, so a shopper could type an email, press Subscribe,
  and never be subscribed to anything. Shown only once the stall is full
  enough to have news: four or more products (`Emakola.Themes.Layout`).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "electronics/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""},
      %{key: "button_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    settings = assigns[:settings]

    assigns =
      assigns
      |> assign(:layout, Layout.of(assigns))
      |> assign(:heading, setting(settings, "heading", newsletter_title(assigns.theme)))
      |> assign(
        :subheading,
        setting(settings, "subheading", newsletter_subtitle(assigns.theme, assigns.store))
      )
      |> assign(
        :button_label,
        setting(settings, "button_label", newsletter_button(assigns.theme))
      )

    ~H"""
    <%!-- NEWSLETTER --%>
    <section
      :if={section_enabled?(@theme, :newsletter) && @layout.show_newsletter?}
      class="bg-[#0A0F1F] py-14 sm:py-20"
    >
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="electronics-heading text-3xl sm:text-4xl font-bold text-white mb-3">
          {@heading}
        </h2>
        <p class="text-sm text-white/70 mb-7">{@subheading}</p>
        <form
          class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
          phx-submit="subscribe_newsletter"
        >
          <label for="electronics-newsletter-email" class="sr-only">Email</label>
          <input
            type="email"
            id="electronics-newsletter-email"
            name="email"
            required
            placeholder="Enter your email"
            class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-white/50 focus:outline-none focus:ring-2 focus:ring-[#0EA5E9] text-sm"
          />
          <button
            type="submit"
            class="px-7 py-3.5 rounded-full bg-white text-[#0A0F1F] text-sm font-bold hover:bg-[#F5EFE5] transition-colors min-h-[48px]"
          >
            {@button_label}
          </button>
        </form>
      </div>
    </section>
    """
  end

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "Subscribe to our newsletter"

  # "New launches and exclusive offers" promised offers on the merchant's
  # behalf. Blank, the section says only what it can.
  defp newsletter_subtitle(theme, store) do
    present(get_in(theme, [:newsletter, :subtitle])) ||
      "New products and updates from #{store.name}, straight to your inbox."
  end

  defp newsletter_button(theme),
    do: get_in(theme, [:newsletter, :button_text]) || "Subscribe"
end
