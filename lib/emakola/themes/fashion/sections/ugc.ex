defmodule Emakola.Themes.Fashion.Sections.Ugc do
  @moduledoc """
  Fashion home "Worn by you" strip — extracted verbatim from fashion/home.ex.

  Placeholder-only: the six tiles are camera glyphs, not customer photographs,
  which is why the theme ships this section switched OFF (`sections.ugc =
  false`) and merchants must opt in. Moved as found — see the retrofit report.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Fashion.Shared

  @impl true
  def key, do: "fashion/ugc"

  @impl true
  def label, do: "Customer photos"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={Shared.section_enabled?(@theme, :ugc)} class="bg-[#FAF6EE] py-14 sm:py-20">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-3">
          Tag &commat;{String.downcase(String.replace(@store.name, " ", ""))}
        </p>
        <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-[#1C1917] mb-10">
          Worn by you.
        </h2>
        <div class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-2 sm:gap-3">
          <div
            :for={_ <- 1..6}
            class="aspect-square bg-gradient-to-br from-[#E7E5E4] to-[#D6D3D1] flex items-center justify-center"
          >
            <span class="material-symbols-outlined text-[#5B21B6]/30" style="font-size: 40px;">
              photo_camera
            </span>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
