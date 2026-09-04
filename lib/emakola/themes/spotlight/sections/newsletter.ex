defmodule Emakola.Themes.Spotlight.Sections.Newsletter do
  @moduledoc """
  Spotlight home newsletter band.

  The form fires `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription`. It was the most thoroughly inert
  of the six: no `phx-submit`, no `name` on the input, and a `type="button"`
  submit that would not even have submitted the form. Still gated by the legacy
  `@theme.sections.newsletter` toggle underneath the section editor's own
  `enabled` flag. Shown only once the shop is full enough to have news: four
  or more products, per the shared `Layout` plan — a one-product shop, the
  theme's whole premise, asks for no email.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout
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
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.show_newsletter? && Shared.section_enabled?(@theme, :newsletter)}
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
      <form class="flex max-w-md mx-auto mt-6 gap-2" phx-submit="subscribe_newsletter">
        <label for="spotlight-newsletter-email" class="sr-only">Email address</label>
        <input
          type="email"
          id="spotlight-newsletter-email"
          name="email"
          required
          placeholder="you@email.com"
          class="flex-1 px-4 py-3 rounded-full border border-[#ECE7DE] text-sm focus:outline-none focus:border-[var(--theme-accent,#7C3AED)]"
        />
        <button type="submit" class="rounded-full spot-cta px-6 py-3 text-sm font-semibold">
          {if @settings["cta_label"] not in [nil, ""],
            do: @settings["cta_label"],
            else: get_in(@theme, [:newsletter, :button_text]) || "Subscribe"}
        </button>
      </form>
    </section>
    """
  end
end
