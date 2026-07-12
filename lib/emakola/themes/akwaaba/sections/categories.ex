defmodule Emakola.Themes.Akwaaba.Sections.Categories do
  @moduledoc """
  Akwaaba category tiles — photographs with an overlay label and a pill CTA.

  Each tile borrows the photograph of a product in that category, so a merchant
  gets a photo-led category rail without having to shoot category art they do
  not have. With no photo at all the tile falls back to a warm ground and the
  category's initial.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Akwaaba.Shared

  @impl true
  def key, do: "akwaaba/categories"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Shop by category"}]
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :tiles,
        tiles(
          assigns.categories,
          Map.get(assigns, :products, []),
          Map.get(assigns, :category_photos) || %{}
        )
      )

    ~H"""
    <section
      :if={@tiles != []}
      class="bg-white px-5 pb-4 [font-family:var(--akwaaba-body)] sm:px-10"
      aria-labelledby="akwaaba-categories-heading"
    >
      <div class="mx-auto max-w-[1320px]">
        <h2
          id="akwaaba-categories-heading"
          class="text-3xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)] sm:text-4xl"
        >
          {@settings["heading"] || "Shop by category"}
        </h2>

        <ul class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <li :for={{category, image} <- @tiles} class="group">
            <a
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="relative block aspect-[4/3] overflow-hidden rounded-3xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2"
            >
              <%!-- A category can only borrow a photograph from a product the
              home page happens to have loaded, and Category carries no image of
              its own. So a photo-less tile must look *designed*, not failed: a
              warm terracotta ground with the category's initial cut into it,
              carrying the same label and pill as its photographed neighbours.
              A grid where some tiles look finished and others look empty reads
              as a bug even when it is working. --%>
              <div
                :if={is_nil(image)}
                class="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-[#F3D3C0] via-[#E9B99F] to-[#D99873]"
                aria-hidden="true"
              >
                <span class="select-none text-7xl text-white/70 [font-family:var(--akwaaba-display)]">
                  {String.first(category.name)}
                </span>
              </div>

              <Shared.photo_or_initial
                :if={image}
                image={image}
                title={category.name}
                sizes={[720, 540]}
              />

              <div
                class="absolute inset-0 bg-gradient-to-t from-black/65 via-black/10 to-transparent"
                aria-hidden="true"
              >
              </div>

              <div class="absolute inset-x-4 bottom-4 flex items-center justify-between gap-3">
                <p class="text-xl text-white [font-family:var(--akwaaba-display)]">{category.name}</p>
                <span class="flex-shrink-0 rounded-full bg-white px-4 py-2 text-xs font-bold text-[color:var(--akwaaba-ink)] motion-safe:transition-colors motion-safe:group-hover:bg-[color:var(--akwaaba-amber)]">
                  View collection
                </span>
              </div>
            </a>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  # A category's tile photo is the photo of the first product filed under it.
  defp tiles(categories, products, covers) do
    for category <- Enum.take(categories, 6) do
      {category, cover(category, products, covers)}
    end
  end

  # The store's real category cover first — it is read from the catalogue, so a
  # category outside the page's capped product preview still gets a photograph.
  # The preview stays as the fallback for callers that pass no covers (admin
  # preview, tests). Both are scoped to the category itself: a tile is a promise
  # about what is behind it.
  defp cover(category, products, covers) do
    Map.get(covers, category.id) ||
      products
      |> Enum.find(&(Map.get(&1, :category_id) == category.id))
      |> case do
        nil -> nil
        product -> Shared.first_image(product)
      end
  end
end
