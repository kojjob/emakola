defmodule Emakola.Themes.Adwuma.Sections.Categories do
  @moduledoc """
  Category tiles on light grey, in the reference's 2×2 grid.

  The reference shows an item count per tile ("05 Items"). There is no such
  aggregate in this codebase, and the home page loads a capped preview of eight
  products — so counting from `@products` would print a number that is wrong for
  any shop with more than eight. A wrong count is worse than no count, so there
  is none.

  Each tile is a real link. `phx-click="filter_category"` is NOT handled by
  StoreLive and would kill the page.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "adwuma/categories"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Shop by category"}]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:categories, Map.get(assigns, :categories) || [])
      |> assign(:photos, Map.get(assigns, :category_photos) || %{})

    ~H"""
    <section
      :if={@categories != []}
      class="bg-white px-4 py-16 [font-family:var(--adw-body)] sm:px-6 sm:py-20"
    >
      <div class="mx-auto max-w-5xl">
        <h2 class="text-center text-2xl font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)] sm:text-3xl">
          {@settings["heading"] || "Shop by category"}
        </h2>

        <div class="mt-10 grid gap-5 sm:grid-cols-2">
          <a
            :for={category <- Enum.take(@categories, 4)}
            href={store_path(@store.slug, "/category/#{category.slug}")}
            class="group overflow-hidden rounded-2xl border border-[color:var(--adw-rule)] bg-[#F4F4F6]"
          >
            <div class="aspect-[16/10] overflow-hidden">
              <img
                :if={Map.get(@photos, category.id)}
                src={Map.get(@photos, category.id)}
                alt={category.name}
                loading="lazy"
                class="h-full w-full object-cover"
              />
              <div
                :if={is_nil(Map.get(@photos, category.id))}
                class="flex h-full w-full items-center justify-center text-4xl font-semibold text-[color:var(--adw-muted)]/40 [font-family:var(--adw-display)]"
              >
                {String.first(category.name)}
              </div>
            </div>
            <p class="px-5 py-4 text-sm font-semibold text-[color:var(--adw-ink)]">
              {category.name}
            </p>
          </a>
        </div>
      </div>
    </section>
    """
  end
end
