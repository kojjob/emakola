defmodule Emakola.Themes.Beauty.Sections.FeaturedIn do
  @moduledoc """
  Beauty "as featured in" brand strip.

  Off by default (`sections.featured_in` is `false` in `Beauty.defaults/0`),
  and the gate is preserved here so a store that never touched it keeps
  rendering nothing.

  Note: the strip repeats a literal placeholder five times — it names no real
  publication and reads no store data. Extracted verbatim; see the retrofit
  report.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "beauty/featured_in"

  @impl true
  def label, do: "Featured in"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={section_enabled?(@theme, :featured_in)} class="bg-[#C9925E]/10 py-8">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex flex-wrap items-center justify-center gap-x-10 gap-y-4 sm:gap-x-16 opacity-70">
          <span :for={_ <- 1..5} class="beauty-heading text-base sm:text-lg italic text-[#6B4423]">
            As featured in
          </span>
        </div>
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
end
