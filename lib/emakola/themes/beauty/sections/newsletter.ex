defmodule Emakola.Themes.Beauty.Sections.Newsletter do
  @moduledoc """
  Beauty newsletter band on walnut.

  The form fires `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription`. It previously carried no
  `phx-submit` and no `name` on its input, so a shopper could type an email,
  press Subscribe, and never be subscribed to anything.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "beauty/newsletter"

  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :text, label: "Subheading", default: ""},
      %{key: "button_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={section_enabled?(@theme, :newsletter)} class="bg-[#6B4423] py-14 sm:py-20">
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="beauty-heading text-3xl sm:text-4xl font-semibold text-[#FAF6EE] mb-3">
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: newsletter_title(@theme)}
        </h2>
        <p class="text-sm text-[#FAF6EE]/75 mb-8">
          {if @settings["subheading"] not in [nil, ""],
            do: @settings["subheading"],
            else: newsletter_subtitle(@theme)}
        </p>
        <form
          class="flex flex-col sm:flex-row gap-3 max-w-lg mx-auto"
          phx-submit="subscribe_newsletter"
        >
          <label for="beauty-newsletter-email" class="sr-only">Email</label>
          <input
            type="email"
            id="beauty-newsletter-email"
            name="email"
            required
            placeholder="Enter your email"
            class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-[#FAF6EE]/50 focus:outline-none focus:ring-2 focus:ring-[#C9925E] text-sm"
          />
          <button
            type="submit"
            class="px-7 py-3.5 rounded-full bg-[var(--theme-accent,#C9925E)] text-[#3D2F25] text-sm font-bold hover:bg-[#FAF6EE] transition-colors min-h-[48px]"
          >
            {if @settings["button_label"] not in [nil, ""],
              do: @settings["button_label"],
              else: newsletter_button(@theme)}
          </button>
        </form>
      </div>
    </section>
    """
  end

  defp section_enabled?(theme, name) do
    case get_in(theme, [:sections, name]) do
      false -> false
      _ -> true
    end
  end

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "Join the list"

  defp newsletter_subtitle(theme),
    do: get_in(theme, [:newsletter, :subtitle]) || "New launches, first."

  defp newsletter_button(theme),
    do: get_in(theme, [:newsletter, :button_text]) || "Subscribe"
end
