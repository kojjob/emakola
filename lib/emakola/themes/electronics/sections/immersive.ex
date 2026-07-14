defmodule Emakola.Themes.Electronics.Sections.Immersive do
  @moduledoc """
  Electronics home "Immersive Sound, Unmatched Comfort" split -- extracted
  verbatim from electronics/home.ex: a 2x2 product mini-grid beside a
  lifestyle panel. Its heading is fixed theme copy, so it exposes no
  settings.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Electronics.Shared

  @impl true
  def key, do: "electronics/immersive"
  @impl true
  def label, do: "Immersive split"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :immersive_grid, Enum.take(assigns[:products] || [], 4))

    ~H"""
    <%!-- IMMERSIVE: split grid + lifestyle --%>
    <section
      :if={section_enabled?(@theme, :immersive) && @immersive_grid != []}
      class="bg-[#F5EFE5] py-14 sm:py-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-8">
          <h2 class="electronics-heading text-3xl sm:text-4xl font-extrabold text-[#134E4A]">
            Immersive Sound,<br />Unmatched Comfort
          </h2>
          <span class="hidden sm:inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white border border-[#E5E7EB] text-xs font-semibold text-[#134E4A]">
            <span class="material-symbols-outlined" style="font-size: 14px;">filter_list</span>
            Few products
          </span>
        </div>
        <div class="grid lg:grid-cols-2 gap-5">
          <div class="grid grid-cols-2 gap-4">
            <Shared.product_card :for={product <- @immersive_grid} product={product} store={@store} />
          </div>
          <div class="aspect-square lg:aspect-auto rounded-2xl overflow-hidden bg-gradient-to-br from-[#0F4A45] via-[#134E4A] to-[#0E3F3B] relative">
            <span class="absolute inset-0 flex items-center justify-center">
              <span class="material-symbols-outlined text-[#0EA5E9]/30" style="font-size: 200px;">
                headphones
              </span>
            </span>
            <div class="absolute bottom-6 left-6 right-6">
              <p class="electronics-heading text-2xl font-bold text-white mb-1">
                Premium audio gear
              </p>
              <%!-- Was "Hand-picked for clarity, comfort, and battery life." —
                   an assertion that someone at this shop auditioned the gear on
                   three specific criteria. Nobody did. --%>
              <p class="text-sm text-white/70 mb-4">
                Browse the range.
              </p>
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-white text-[#134E4A] text-xs font-bold hover:bg-[#F5EFE5] transition-colors"
              >
                Learn More
                <span class="material-symbols-outlined" style="font-size: 14px;">
                  arrow_forward
                </span>
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
