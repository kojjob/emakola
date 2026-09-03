defmodule Emakola.Themes.Bold.Sections.Newsletter do
  @moduledoc """
  Bold home newsletter — dark band, amber CTA — extracted verbatim from
  bold/home.ex.

  `subscribe_newsletter` is handled globally (EmakolaWeb newsletter hook),
  so the form stays live inside the section editor's preview. Shown only
  once the shop is full enough to have news: four or more products, per the
  shared `Layout` plan.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Bold.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "bold/newsletter"
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
    settings = assigns[:settings] || %{}

    assigns =
      assigns
      |> assign(:layout, Layout.of(assigns))
      |> assign(:heading, override(settings["heading"], "Stay in the Know"))
      |> assign(
        :subheading,
        override(
          settings["subheading"],
          "New drops, editorial picks, and exclusive access delivered to your inbox."
        )
      )
      |> assign(:button_label, override(settings["button_label"], "Subscribe"))

    ~H"""
    <section
      :if={@layout.show_newsletter? and Shared.section_enabled?(@theme, :newsletter)}
      class="py-16 sm:py-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-[#0F172A] px-6 sm:px-12 lg:px-20 py-14 sm:py-20 text-center">
          <h2
            class="text-2xl sm:text-3xl lg:text-4xl font-bold text-white mb-4"
            style="font-family: 'Outfit', sans-serif;"
          >
            {@heading}
          </h2>
          <p
            class="text-slate-400 text-base mb-8 max-w-md mx-auto"
            style="font-family: 'Inter', sans-serif;"
          >
            {@subheading}
          </p>
          <form
            class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
            phx-submit="subscribe_newsletter"
          >
            <input
              type="email"
              name="email"
              placeholder="Your email address"
              required
              class="flex-1 px-5 py-3.5 bg-slate-800 text-white placeholder:text-slate-500 border border-slate-700 text-sm focus:outline-none focus:border-[#F59E0B] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            />
            <button
              type="submit"
              class="px-8 py-3.5 bg-[#F59E0B] text-[#0F172A] text-sm font-bold hover:bg-[#D97706] active:scale-[0.97] transition-all tracking-wide uppercase"
              style="font-family: 'Inter', sans-serif;"
            >
              {@button_label}
            </button>
          </form>
        </div>
      </div>
    </section>
    """
  end

  defp override(setting, fallback) when setting in [nil, ""], do: fallback
  defp override(setting, _fallback), do: setting
end
