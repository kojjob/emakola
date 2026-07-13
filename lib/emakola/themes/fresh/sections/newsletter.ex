defmodule Emakola.Themes.Fresh.Sections.Newsletter do
  @moduledoc """
  Fresh home newsletter capture. The form fires `subscribe_newsletter`,
  handled platform-wide by `EmakolaWeb.Hooks.NewsletterSubscription` — no
  per-view handler needed. Extracted verbatim from `fresh/home.ex`; the
  merchant's `@theme.newsletter` config stays the fallback behind the
  section settings.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Fresh.Shared

  @impl true
  def key, do: "fresh/newsletter"
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
    ~H"""
    <section :if={Shared.section_enabled?(@theme, :newsletter)} class="py-10">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-[#FEF9C3] rounded-3xl p-8 sm:p-12 text-center">
          <h2
            class="text-2xl sm:text-3xl font-bold text-cta-dark mb-3"
            style="font-family: 'Nunito', sans-serif;"
          >
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: @theme.newsletter.title || "Get Weekly Deals & Recipes"}
          </h2>
          <p
            class="text-[#78350F] text-base mb-6 max-w-md mx-auto"
            style="font-family: 'Inter', sans-serif;"
          >
            {if @settings["subheading"] not in [nil, ""],
              do: @settings["subheading"],
              else:
                @theme.newsletter.subtitle ||
                  "Fresh picks, seasonal specials, and recipes delivered to your inbox."}
          </p>
          <form
            class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
            phx-submit="subscribe_newsletter"
          >
            <input
              type="email"
              name="email"
              placeholder="Enter your email"
              required
              class="flex-1 px-5 py-3.5 rounded-full bg-white text-cta-dark placeholder:text-[#92400E]/40 border border-[#D9F99D] focus:outline-none focus:ring-2 focus:ring-[#059669] focus:border-transparent text-sm shadow-sm"
              style="font-family: 'Inter', sans-serif;"
            />
            <button
              type="submit"
              class="px-8 py-3.5 bg-[var(--theme-primary,#047857)] text-white rounded-full text-sm font-bold hover:opacity-90 active:scale-[0.97] transition-all shadow-lg shadow-emerald-200"
              style="font-family: 'Inter', sans-serif;"
            >
              {if @settings["button_label"] not in [nil, ""],
                do: @settings["button_label"],
                else: @theme.newsletter.button_text || "Subscribe"}
            </button>
          </form>
        </div>
      </div>
    </section>
    """
  end
end
