defmodule Emakola.Themes.Pharmacy.Sections.CategoryStrip do
  @moduledoc """
  Pharmacy home category pill strip — mint pills, up to seven categories.
  Extracted verbatim from `pharmacy/home.ex`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/category_strip"

  @impl true
  def label, do: "Category pills"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={
        Shared.section_enabled?(@theme, :categories) && @categories != [] &&
          @layout.show_categories?
      }
      class="bg-[#F9F6F0] pb-10"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex flex-wrap items-center gap-2 sm:gap-3">
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex items-center px-4 py-2 rounded-full bg-[#14543E] text-white text-sm font-semibold"
          >
            All Products
          </a>
          <a
            :for={category <- Enum.take(@categories, 7)}
            href={store_path(@store.slug, "/category/#{category.slug}")}
            class="inline-flex items-center px-4 py-2 rounded-full bg-[#A7E5C5]/40 text-[#14543E] text-sm font-medium hover:bg-[#A7E5C5] transition-colors"
          >
            {category.name}
          </a>
        </div>
      </div>
    </section>
    """
  end
end
