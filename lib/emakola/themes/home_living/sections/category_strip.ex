defmodule Emakola.Themes.HomeLiving.Sections.CategoryStrip do
  @moduledoc """
  Home Living "Shop by categories" strip — extracted verbatim from
  home_living/home.ex.

  The rooms come from `@theme.rooms.items` (a list of icon/name maps), which
  no flat setting type can express — so the section declares no settings and
  keeps reading the theme config, exactly as before. It was the one block on
  the page with no legacy `sections.*` toggle; the section editor's `enabled`
  flag is now its first off switch.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Item
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "home_living/category_strip"
  @impl true
  def label, do: "Shop by categories"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :rooms,
        rooms_items(assigns.theme, assigns[:categories] || [], Layout.of(assigns))
      )

    ~H"""
    <section :if={@rooms != []} class="bg-white py-10 sm:py-12 border-b border-[#E5E7EB]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-end">
          <div class="lg:col-span-3">
            <h2 class="home-living-heading text-3xl sm:text-4xl font-bold text-[#1F2937] leading-tight">
              Shop<br />by categories
            </h2>
          </div>
          <div class="lg:col-span-9 grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
            <a
              :for={room <- @rooms}
              href={store_path(@store.slug, Item.field(room, :href) || "/products")}
              class="group bg-[#F3F4F6] rounded-2xl p-4 sm:p-5 hover:bg-[#1F2937] hover:text-white transition-colors min-h-[120px] flex flex-col justify-between"
            >
              <span
                class="material-symbols-outlined text-[#1F2937] group-hover:text-[#84CC16] transition-colors"
                style="font-size: 28px;"
              >
                {Item.field(room, :icon, "chair")}
              </span>
              <p class="text-sm font-semibold mt-3">
                {Item.field(room, :name)}
              </p>
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # The grid used to invent four furniture rooms for every shop wearing the
  # theme. The merchant's own rooms always show; otherwise the store's real
  # categories fill it once the stall is full enough to need sorting
  # (`Layout`: four or more products), and a shop with none shows no grid.
  defp rooms_items(theme, categories, layout) do
    merchant_items = get_in(theme, [:rooms, :items])

    cond do
      is_list(merchant_items) and merchant_items != [] ->
        merchant_items

      layout.show_categories? ->
        categories
        |> Enum.take(4)
        |> Enum.map(fn category ->
          %{name: category.name, icon: "category", href: "/category/#{category.slug}"}
        end)

      true ->
        []
    end
  end
end
