defmodule Emakola.Themes.Electronics.Sections.Bestsellers do
  @moduledoc """
  Electronics home "Best selling product" grid -- extracted verbatim from
  electronics/home.ex. It shows the three products after the featured and
  immersive blocks (`Helpers.slots/1`), so nothing is shown twice.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Electronics.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "electronics/bestsellers"
  @impl true
  def label, do: "More products"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    # These are the next products in catalog order. Nothing here is derived from
    # sales: the platform knows what each store has sold, and this never asked.
    # Calling them "Best selling" told every shopper a fact about a ranking that
    # does not exist. They are simply more of the shop, so that is what they say.
    best_sellers = assigns |> Layout.of() |> slots() |> Map.fetch!(:more)

    assigns =
      assigns
      |> assign(:best_sellers, best_sellers)
      |> assign(:heading, setting(assigns[:settings], "heading", "More from the shop"))

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
