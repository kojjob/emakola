defmodule Emakola.Themes.Starter.Sections.Newsletter do
  @moduledoc "Starter home newsletter section -- extracted verbatim from starter/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Starter.Sections.Helpers

  @impl true
  def key, do: "starter/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={section_enabled?(@theme, :newsletter)}
      class="py-12"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-[#F8FAFC] rounded-2xl p-8 sm:p-12 text-center">
          <h2
            class="text-2xl font-semibold text-[#0F172A] mb-2"
            style="font-family: 'Inter', sans-serif;"
          >
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: @theme.newsletter.title}
          </h2>
          <p
            class="text-[#64748B] text-sm mb-6 max-w-md mx-auto"
            style="font-family: 'Inter', sans-serif;"
          >
            {@theme.newsletter.subtitle}
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
              class="flex-1 px-5 py-3 rounded-full bg-white text-[#0F172A] placeholder:text-[#94A3B8] border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[var(--theme-primary,#6366F1)] focus:border-transparent text-sm"
              style="font-family: 'Inter', sans-serif;"
            />
            <button
              type="submit"
              class="px-8 py-3 bg-[var(--theme-primary,#6366F1)] text-white rounded-full text-sm font-semibold hover:bg-[#4F46E5] active:scale-[0.97] transition-all"
              style="font-family: 'Inter', sans-serif;"
            >
              {@theme.newsletter.button_text}
            </button>
          </form>
        </div>
      </div>
    </section>
    """
  end
end
