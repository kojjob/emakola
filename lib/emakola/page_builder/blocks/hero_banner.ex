defmodule Emakola.PageBuilder.Blocks.HeroBanner do
  @moduledoc """
  Top-of-page banner block. Full-bleed image (or amber gradient fallback)
  with overlay headline, optional subheadline, and up to two CTA buttons.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `image_url` | string \\| nil | nil |
  | `headline` | string | "Welcome" |
  | `subheadline` | string \\| nil | nil |
  | `cta_label` | string \\| nil | "Shop now" |
  | `cta_url` | string \\| nil | "/products" |
  | `secondary_cta_label` | string \\| nil | nil |
  | `secondary_cta_url` | string \\| nil | nil |
  | `text_align` | "left" \\| "center" \\| "right" | "left" |
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  alias Emakola.PageBuilder.SafeUrl

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  @impl true
  def type, do: "hero_banner"

  @impl true
  def name, do: "Hero Banner"

  @impl true
  def icon, do: "view_carousel"

  @impl true
  def default_content do
    %{
      image_url: nil,
      headline: "Welcome",
      subheadline: nil,
      cta_label: "Shop now",
      cta_url: "/products",
      secondary_cta_label: nil,
      secondary_cta_url: nil,
      text_align: "left"
    }
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :align_class, align_class(assigns.content[:text_align]))

    ~H"""
    <section class="relative overflow-hidden">
      <%= if @content[:image_url] do %>
        <div class="relative aspect-[4/5] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[80vh]">
          <.optimized_image
            src={SafeUrl.safe_url(@content[:image_url])}
            alt={@content[:headline] || @store.name}
            priority={:high}
            class="absolute inset-0 w-full h-full object-cover"
          />
          <div class="absolute inset-0 bg-gradient-to-t from-[#1C1917]/80 via-[#1C1917]/30 to-transparent">
          </div>
          <.hero_overlay
            content={@content}
            store={@store}
            align_class={@align_class}
          />
        </div>
      <% else %>
        <div class="relative bg-gradient-to-br from-[#B45309] via-[#D97706] to-[#F59E0B] py-20 sm:py-28 lg:py-36">
          <.hero_overlay
            content={@content}
            store={@store}
            align_class={@align_class}
          />
        </div>
      <% end %>
    </section>
    """
  end

  @impl true
  def edit_form(assigns) do
    ~H"""
    <p class="text-sm text-[#78716C]">
      Edit form coming in Phase 2 of the page builder.
    </p>
    """
  end

  attr :content, :map, required: true
  attr :store, :map, required: true
  attr :align_class, :string, required: true

  defp hero_overlay(assigns) do
    ~H"""
    <div class={["absolute inset-0 flex items-center", align_to_flex(@align_class)]}>
      <div class="relative w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-16">
        <div class={["max-w-2xl", @align_class]}>
          <h1
            class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-[1.05] mb-4"
            style="font-family: 'Manrope', sans-serif;"
          >
            {@content[:headline] || "Welcome"}
          </h1>
          <p
            :if={@content[:subheadline]}
            class="text-base sm:text-lg text-white/90 leading-relaxed mb-7 max-w-lg"
            style="font-family: 'Inter', sans-serif;"
          >
            {@content[:subheadline]}
          </p>
          <div class={["flex flex-wrap gap-3", justify_class(@align_class)]}>
            <a
              :if={@content[:cta_label]}
              href={SafeUrl.safe_url(@content[:cta_url]) || "/products"}
              class="inline-flex items-center gap-2 px-7 py-3.5 bg-white text-[#1C1917] rounded-full text-sm sm:text-base font-bold hover:bg-[#FEF3C7] active:scale-[0.97] transition-all shadow-lg shadow-black/20"
              style="font-family: 'Inter', sans-serif;"
            >
              {@content[:cta_label]}
            </a>
            <a
              :if={@content[:secondary_cta_label]}
              href={SafeUrl.safe_url(@content[:secondary_cta_url]) || "/products"}
              class="inline-flex items-center gap-2 px-6 py-3.5 bg-white/10 text-white rounded-full text-sm sm:text-base font-semibold hover:bg-white/20 backdrop-blur-sm transition-all border border-white/30"
              style="font-family: 'Inter', sans-serif;"
            >
              {@content[:secondary_cta_label]}
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp align_class("center"), do: "text-center mx-auto"
  defp align_class("right"), do: "text-right ml-auto"
  defp align_class(_), do: "text-left"

  defp align_to_flex("text-center mx-auto"), do: "justify-center"
  defp align_to_flex("text-right ml-auto"), do: "justify-end"
  defp align_to_flex(_), do: "justify-start"

  defp justify_class("text-center mx-auto"), do: "justify-center"
  defp justify_class("text-right ml-auto"), do: "justify-end"
  defp justify_class(_), do: "justify-start"
end
