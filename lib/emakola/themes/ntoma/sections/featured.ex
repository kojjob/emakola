defmodule Emakola.Themes.Ntoma.Sections.Featured do
  @moduledoc """
  Ntoma featured piece — one editorial split card for the most recent
  active product: photograph (placeholder-first), oversized garment-label
  price tag, serif title, and the section's primary CTA.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Ntoma.Shared

  @impl true
  def key, do: "ntoma/featured"
  @impl true
  def label, do: "Featured piece"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Eyebrow label", default: "Featured"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@products != []}
      class="px-4 py-10 sm:px-6 sm:py-14 lg:px-8"
      aria-label="Featured piece"
    >
      <div class="mx-auto max-w-[1280px]">
        <Shared.featured_card
          product={List.first(@products)}
          store={@store}
          eyebrow={
            if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Featured"
          }
        />
      </div>
    </section>
    """
  end
end
