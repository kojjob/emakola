defmodule Emakola.Themes.Fashion.Sections.Newsletter do
  @moduledoc """
  Fashion home newsletter band — extracted verbatim from fashion/home.ex.

  The form is carried across exactly as it stands today: no `phx-submit`, no
  `name` on the input. It captures nothing — see the retrofit report; wiring it
  to the platform's `subscribe_newsletter` handler is a behaviour change and
  belongs in its own commit.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Fashion.Shared

  @impl true
  def key, do: "fashion/newsletter"

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
    theme = assigns.theme

    assigns =
      assigns
      |> assign(:newsletter_title, setting_or(assigns, "heading", newsletter_title(theme)))
      |> assign(
        :newsletter_subtitle,
        setting_or(assigns, "subheading", newsletter_subtitle(theme))
      )
      |> assign(
        :newsletter_button,
        setting_or(assigns, "button_label", newsletter_button(theme))
      )

    ~H"""
    <section :if={Shared.section_enabled?(@theme, :newsletter)} class="bg-[#5B21B6] py-14 sm:py-20">
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-3">
          The List
        </p>
        <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-white mb-3">
          {@newsletter_title}
        </h2>
        <p class="text-sm text-white/70 mb-8 italic fashion-heading">
          {@newsletter_subtitle}
        </p>
        <form class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
          <label for="fashion-newsletter-email" class="sr-only">Email</label>
          <input
            type="email"
            id="fashion-newsletter-email"
            placeholder="Enter your email"
            class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-white/50 focus:outline-none focus:ring-2 focus:ring-[#D97706] text-sm"
          />
          <button
            type="submit"
            class="px-7 py-3.5 rounded-full bg-[var(--theme-accent,#D97706)] text-white text-xs font-bold uppercase tracking-wider hover:bg-[#B45309] transition-colors min-h-[48px]"
          >
            {@newsletter_button}
          </button>
        </form>
      </div>
    </section>
    """
  end

  # ── Helpers ──

  defp setting_or(assigns, key, fallback) do
    case assigns[:settings][key] do
      value when value not in [nil, ""] -> value
      _blank -> fallback
    end
  end

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "First access. No noise."

  defp newsletter_subtitle(theme),
    do:
      get_in(theme, [:newsletter, :subtitle]) ||
        "Be the first to shop new drops, runway looks, and editor picks."

  defp newsletter_button(theme),
    do: get_in(theme, [:newsletter, :button_text]) || "Join the List"
end
