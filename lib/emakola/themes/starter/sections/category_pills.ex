defmodule Emakola.Themes.Starter.Sections.CategoryPills do
  @moduledoc "Starter home category pills -- extracted verbatim from starter/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Starter.Sections.Helpers

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Starter.Shared

  @impl true
  def key, do: "starter/category_pills"
  @impl true
  def label, do: "Category Pills"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={section_enabled?(@theme, :categories) and @categories != [] and @layout.show_categories?}
      class="py-6 bg-white"
      aria-label="Product categories"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <h2
          class="text-lg font-semibold text-[#0F172A] mb-4"
          style="font-family: 'Inter', sans-serif;"
        >
          Shop by Category
        </h2>
        <div
          class="flex gap-3 overflow-x-auto pb-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
          role="list"
        >
          <Shared.category_pill
            :for={category <- @categories}
            category={category}
            store_slug={@store.slug}
          />
        </div>
      </div>
    </section>
    """
  end
end
