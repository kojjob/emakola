defmodule Emakola.Themes.HomeLiving.Sections.BrandStory do
  @moduledoc """
  Home Living brand-story split — extracted verbatim from
  home_living/home.ex.

  The body falls back, as before, to the store's own description and then to
  the theme's stock paragraph. Settings are additive: a blank default keeps
  that chain intact. Still gated by the legacy `@theme.sections.brand_story`
  toggle underneath the section editor's own `enabled` flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.HomeLiving.Shared

  @default_body "We work with local craftspeople to bring you furniture that lasts. Solid wood, natural fibres, no fast-furniture shortcuts. Delivered across all 16 regions of Ghana."

  @impl true
  def key, do: "home_living/brand_story"
  @impl true
  def label, do: "Brand story"

  @impl true
  def settings_schema do
    [
      %{key: "eyebrow", type: :string, label: "Eyebrow", default: ""},
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "body", type: :text, label: "Body", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:eyebrow, present(assigns.settings["eyebrow"]) || "Our story")
      |> assign(
        :heading,
        present(assigns.settings["heading"]) || "Built in Ghana, made for life."
      )
      |> assign(
        :body,
        present(assigns.settings["body"]) || assigns.store.description || @default_body
      )

    ~H"""
    <section :if={Shared.section_enabled?(@theme, :brand_story)} class="bg-[#FAF7F2] py-16 sm:py-24">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <div class="aspect-[4/3] rounded-3xl bg-gradient-to-br from-[#374151] to-[#1F2937] flex items-center justify-center overflow-hidden">
            <span class="material-symbols-outlined text-[#84CC16]/40" style="font-size: 140px;">
              home
            </span>
          </div>
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#C2410C] mb-3">
              {@eyebrow}
            </p>
            <h2 class="home-living-heading text-3xl sm:text-4xl font-bold text-[#1F2937] mb-5 leading-tight">
              {@heading}
            </h2>
            <p class="text-base text-[#4B5563] leading-relaxed mb-3">
              {@body}
            </p>
            <a
              href={store_path(@store.slug, "/about")}
              class="inline-flex items-center gap-1 mt-4 text-sm font-semibold text-[#1F2937] hover:gap-2 transition-all"
            >
              Read more
              <span class="material-symbols-outlined" style="font-size: 16px;">arrow_forward</span>
            </a>
          </div>
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
