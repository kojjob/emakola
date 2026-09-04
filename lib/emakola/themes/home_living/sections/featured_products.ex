defmodule Emakola.Themes.HomeLiving.Sections.FeaturedProducts do
  @moduledoc """
  Home Living "Popular products" grid — extracted verbatim from
  home_living/home.ex.

  Shows up to `limit` products (8 before the retrofit, the default here) of
  the catalogue minus the featured pick (`Emakola.Themes.Layout`), so nothing
  is shown twice; a one-product shop is carried by the pick alone. Like the
  original, it renders nothing at all when there is nothing to show.
  Still gated by the legacy `@theme.sections.featured_products` toggle
  underneath the section editor's own `enabled` flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.HomeLiving.Shared
  alias Emakola.Themes.Layout

  @default_limit 8

  @impl true
  def key, do: "home_living/featured_products"
  @impl true
  def label, do: "Featured products"

  @impl true
  def settings_schema do
    [
      %{key: "eyebrow", type: :string, label: "Eyebrow", default: ""},
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "limit", type: :integer, label: "Products shown", default: @default_limit}
    ]
  end

  @impl true
  def render(assigns) do
    layout = Layout.of(assigns)

    assigns =
      assigns
      |> assign(
        :featured_products,
        Enum.take(layout.grid_products, limit(assigns.settings["limit"]))
      )
      |> assign(:eyebrow, present(assigns.settings["eyebrow"]) || "From the shop")
      |> assign(:heading, present(assigns.settings["heading"]) || "Featured products")

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :featured_products) && @featured_products != []}
      class="bg-[#FAF7F2] py-14 sm:py-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-8">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#C2410C] mb-2">
              {@eyebrow}
            </p>
            <h2 class="home-living-heading text-3xl sm:text-4xl font-bold text-[#1F2937]">
              {@heading}
            </h2>
          </div>
          <a
            href={store_path(@store.slug, "/products")}
            class="hidden sm:inline-flex items-center gap-1 text-sm font-semibold text-[#1F2937] hover:gap-2 transition-all"
          >
            View all
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
          <Shared.product_card :for={product <- @featured_products} product={product} store={@store} />
        </div>
      </div>
    </section>
    """
  end

  defp limit(value) when is_integer(value) and value >= 0, do: value
  defp limit(_value), do: @default_limit

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
