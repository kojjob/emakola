defmodule Emakola.Themes.Bold.Sections.ProductGrid do
  @moduledoc """
  Bold home product grid — clean 3-column editorial grid — extracted
  verbatim from bold/home.ex.

  Shows the catalogue after the featured bento's three, so nothing on the
  page appears twice; with three products or fewer the bento carries them
  all and the grid stays off the page.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Bold.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "bold/product_grid"
  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "cta_label", type: :string, label: "Link label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    settings = assigns[:settings] || %{}

    assigns =
      assigns
      |> assign(:grid_products, Shared.grid_products(Layout.of(assigns)))
      |> assign(:heading, override(settings["heading"], "The Collection"))
      |> assign(:cta_label, override(settings["cta_label"], "View All"))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :products) and @grid_products != []}
      class="py-12 sm:py-16 bg-[#F8FAFC]"
      aria-labelledby="bold-shop-all"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-10">
          <h2
            id="bold-shop-all"
            class="text-2xl sm:text-3xl font-bold text-[#0F172A]"
            style="font-family: 'Outfit', sans-serif;"
          >
            {@heading}
          </h2>
          <a
            href={store_path(@store.slug, "/products")}
            class="text-sm font-medium text-[#64748B] hover:text-[#0F172A] transition-colors border-b border-[#64748B] hover:border-[#0F172A] pb-0.5"
            style="font-family: 'Inter', sans-serif;"
          >
            {@cta_label}
          </a>
        </div>
        <div class="grid grid-cols-2 gap-6 sm:gap-8 lg:grid-cols-3 lg:gap-10">
          <Shared.product_card :for={product <- @grid_products} product={product} store={@store} />
        </div>
      </div>
    </section>
    """
  end

  defp override(setting, fallback) when setting in [nil, ""], do: fallback
  defp override(setting, _fallback), do: setting
end
