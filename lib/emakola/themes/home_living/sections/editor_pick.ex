defmodule Emakola.Themes.HomeLiving.Sections.EditorPick do
  @moduledoc """
  Home Living "Featured pick" split panel — extracted verbatim from
  home_living/home.ex.

  The pick is the store's first product, as it was before the retrofit, and
  the panel renders nothing when the store has none. Still gated by the
  legacy `@theme.sections.editor_pick` toggle underneath the section editor's
  own `enabled` flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.HomeLiving.Shared

  @impl true
  def key, do: "home_living/editor_pick"
  @impl true
  def label, do: "Featured pick"

  @impl true
  def settings_schema do
    [
      %{key: "badge_label", type: :string, label: "Badge", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    products = Map.get(assigns, :products) || []

    assigns =
      assigns
      |> assign(:editor_pick, List.first(products))
      |> assign(:badge_label, present(assigns.settings["badge_label"]) || "Featured pick")
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Shop now")

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :editor_pick) && @editor_pick}
      class="bg-[#FAF7F2] pb-14 sm:pb-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid lg:grid-cols-2 gap-0 rounded-3xl overflow-hidden bg-[#1F2937]">
          <div class="p-8 sm:p-12 lg:p-16 text-white order-2 lg:order-1 flex flex-col justify-center">
            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#84CC16] text-[#1F2937] text-[11px] font-bold uppercase tracking-wider mb-5 self-start">
              <span class="material-symbols-outlined" style="font-size: 12px;">star</span>
              {@badge_label}
            </span>
            <h2 class="home-living-heading text-3xl sm:text-4xl lg:text-5xl font-bold leading-tight mb-5">
              {@editor_pick.title}
            </h2>
            <p
              :if={@editor_pick.description}
              class="text-base text-white/75 leading-relaxed mb-7 max-w-md line-clamp-3"
            >
              {@editor_pick.description}
            </p>
            <div class="flex flex-wrap items-center gap-4 mb-7">
              <span class="home-living-heading text-3xl font-bold text-[#84CC16]">
                {EmakolaWeb.Helpers.Currency.format_price(
                  @editor_pick.min_price || 0,
                  Map.get(@store, :currency, "GHS")
                )}
              </span>
            </div>
            <a
              href={store_path(@store.slug, "/products/#{@editor_pick.slug}")}
              class="inline-flex items-center gap-2 px-7 py-4 rounded-full bg-[#84CC16] text-[#1F2937] text-sm font-bold hover:bg-white transition-colors min-h-[48px] self-start"
            >
              {@cta_label}
              <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
            </a>
          </div>
          <div class="aspect-square lg:aspect-auto order-1 lg:order-2 bg-[#374151]">
            <img
              :if={Shared.first_image(@editor_pick)}
              src={Shared.first_image(@editor_pick)}
              alt={@editor_pick.title}
              class="w-full h-full object-cover"
            />
            <div
              :if={!Shared.first_image(@editor_pick)}
              class="w-full h-full flex items-center justify-center"
            >
              <span class="material-symbols-outlined text-white/30" style="font-size: 140px;">
                chair
              </span>
            </div>
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
