defmodule Emakola.Themes.Fashion.Sections.BrandStory do
  @moduledoc "Fashion home brand-story split — extracted verbatim from fashion/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fashion.Shared

  @impl true
  def key, do: "fashion/brand_story"

  @impl true
  def label, do: "Brand story"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={Shared.section_enabled?(@theme, :brand_story)} class="bg-white py-16 sm:py-24">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <div class="aspect-[3/4] bg-gradient-to-br from-[#5B21B6]/10 to-[#D97706]/10 flex items-center justify-center">
            <span class="material-symbols-outlined text-[#5B21B6]/40" style="font-size: 140px;">
              checkroom
            </span>
          </div>
          <div>
            <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-3">
              Our story
            </p>
            <h2 class="fashion-display text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-[1.05] mb-6">
              Sewn in Accra.<br />Worn worldwide.
            </h2>
            <p class="text-base text-[#57534E] leading-relaxed mb-3 italic fashion-heading">
              {@store.description ||
                "We work with tailors and weavers across Ghana to bring you pieces that carry stories — Ankara prints, kente weaves, and modern silhouettes shaped by hand. Every piece is sewn in small batches; nothing mass-produced."}
            </p>
            <a
              href={store_path(@store.slug, "/about")}
              class="inline-flex items-center gap-2 mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-[#5B21B6] hover:gap-3 transition-all"
            >
              Read the journal
              <span class="material-symbols-outlined" style="font-size: 14px;">arrow_forward</span>
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
