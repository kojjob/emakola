defmodule Emakola.Themes.Vibrant.Sections.Newsletter do
  @moduledoc """
  Vibrant newsletter callout — the dark stone panel with the amber subscribe
  button. `subscribe_newsletter` is handled globally by the storefront LiveView.
  Shown only once the stall is full enough to have news: four or more
  products (`Emakola.Themes.Layout`). Its copy promises nothing on the
  merchant's behalf — it used to offer "First dibs on new arrivals" and
  "exclusive offers".
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Vibrant.Shared

  @impl true
  def key, do: "vibrant/newsletter"

  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [
      %{key: "eyebrow", type: :string, label: "Eyebrow", default: ""},
      %{key: "heading", type: :string, label: "Heading", default: "Stay in the loop"},
      %{key: "body", type: :text, label: "Body", default: ""},
      %{key: "button_label", type: :string, label: "Button label", default: "Subscribe"}
    ]
  end

  @impl true
  def render(assigns) do
    settings = assigns[:settings] || %{}

    assigns =
      assigns
      |> assign(
        :enabled,
        Shared.section_enabled?(assigns.theme, :newsletter) and
          Layout.of(assigns).show_newsletter?
      )
      |> assign(:eyebrow, present(settings["eyebrow"]))
      |> assign(:heading, present(settings["heading"]) || "Stay in the loop")
      |> assign(
        :body,
        present(settings["body"]) ||
          "New products and updates from #{assigns.store.name}, straight to your inbox."
      )
      |> assign(:button_label, present(settings["button_label"]) || "Subscribe")

    ~H"""
    <section :if={@enabled} class="py-10 sm:py-14">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-gradient-to-br from-[#1C1917] to-[#292524] rounded-3xl p-8 sm:p-12 text-center">
          <p
            :if={@eyebrow}
            class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-highlight,#F59E0B)] mb-3"
          >
            {@eyebrow}
          </p>
          <h2
            class="text-2xl sm:text-3xl font-bold text-white mb-3"
            style="font-family: 'Manrope', sans-serif;"
          >
            {@heading}
          </h2>
          <p
            class="text-white/70 text-base mb-6 max-w-md mx-auto"
            style="font-family: 'Inter', sans-serif;"
          >
            {@body}
          </p>
          <form
            class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
            phx-submit="subscribe_newsletter"
          >
            <input
              type="email"
              name="email"
              placeholder="you@example.com"
              required
              class="flex-1 px-5 py-3.5 rounded-full bg-white/10 text-white placeholder:text-white/40 border border-white/20 focus:outline-none focus:ring-2 focus:ring-[var(--theme-highlight,#F59E0B)] focus:border-transparent text-sm"
              style="font-family: 'Inter', sans-serif;"
            />
            <button
              type="submit"
              class="px-8 py-3.5 bg-[var(--theme-primary,#B45309)] text-white rounded-full text-sm font-bold hover:bg-[#92400E] active:scale-[0.97] transition-all shadow-lg shadow-amber-900/30"
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

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
