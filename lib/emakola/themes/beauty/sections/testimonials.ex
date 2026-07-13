defmodule Emakola.Themes.Beauty.Sections.Testimonials do
  @moduledoc """
  Beauty testimonials — four quote cards with an initial avatar.

  Quotes come from the theme's `testimonials.items` config, falling back to
  the theme's built-in set. Both the fallback quotes and the fixed five-star
  row are pre-existing invented social proof, carried over verbatim by the
  section retrofit rather than silently changed — see the retrofit report.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "beauty/testimonials"

  @impl true
  def label, do: "Testimonials"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={section_enabled?(@theme, :testimonials)} class="bg-[#F5EFE5] py-16 sm:py-24">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-12">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#8C5A24] mb-3">
            Testimonials
          </p>
          <h2 class="beauty-heading text-4xl sm:text-5xl font-semibold text-[#3D2F25]">
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: testimonials_title(@theme)}
          </h2>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          <div :for={t <- testimonials_items(@theme)} class="beauty-card p-6">
            <div class="w-12 h-12 rounded-full bg-[#C9925E]/30 flex items-center justify-center mb-4 text-[#6B4423] beauty-heading font-semibold">
              {String.first(t.name)}
            </div>
            <div class="flex items-center gap-1 mb-3">
              <span :for={_ <- 1..5} class="text-[#8C5A24]" style="font-size: 14px;">★</span>
            </div>
            <p class="text-sm text-[#3D2F25] leading-relaxed mb-4 line-clamp-5">
              "{t.quote}"
            </p>
            <p class="text-sm font-semibold text-[#6B4423]">{t.name}</p>
            <p class="text-xs text-[#6B4423]/60">{t.location}</p>
          </div>
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

  defp testimonials_title(theme),
    do: get_in(theme, [:testimonials, :title]) || "Loved by our community"

  defp testimonials_items(theme) do
    case get_in(theme, [:testimonials, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_testimonials()
    end
  end

  defp default_testimonials do
    [
      %{name: "Akua M.", location: "Accra", quote: "My skin has never felt this soft."},
      %{name: "Nana A.", location: "Kumasi", quote: "Beautiful packaging, beautiful results."},
      %{name: "Yaa K.", location: "Takoradi", quote: "Glow in a bottle. Five stars."},
      %{name: "Ama D.", location: "Tema", quote: "Customer service is top-tier."}
    ]
  end
end
