defmodule Emakola.Themes.Electronics.Sections.Bestsellers do
  @moduledoc """
  Electronics home "Best selling product" grid -- extracted verbatim from
  electronics/home.ex. It shows the three products after the four the
  popular grid already carries.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Electronics.Shared

  @impl true
  def key, do: "electronics/bestsellers"
  @impl true
  def label, do: "Best sellers"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    best_sellers = assigns[:products] |> Kernel.||([]) |> Enum.drop(4) |> Enum.take(3)

    assigns =
      assigns
      |> assign(:best_sellers, best_sellers)
      |> assign(:heading, setting(assigns[:settings], "heading", "Best selling product"))

    ~H"""
    <%!-- BEST SELLERS --%>
    <section
      :if={section_enabled?(@theme, :bestsellers) && @best_sellers != []}
      class="bg-[#F5EFE5] pb-14 sm:pb-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-8">
          <h2 class="electronics-heading text-3xl sm:text-4xl font-extrabold text-[#134E4A]">
            {@heading}
          </h2>
          <a
            href={store_path(@store.slug, "/products")}
            class="hidden sm:inline-flex items-center gap-1 text-sm font-semibold text-[#134E4A] hover:gap-2 transition-all"
          >
            See all
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>
        <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
          <Shared.product_card :for={product <- @best_sellers} product={product} store={@store} />
        </div>
      </div>
    </section>
    """
  end
end
