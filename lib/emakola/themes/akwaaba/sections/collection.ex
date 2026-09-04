defmodule Emakola.Themes.Akwaaba.Sections.Collection do
  @moduledoc """
  Akwaaba product grid — rounded photo cards with quick add.

  The grid shows the catalogue minus the featured product (the wordmark card
  carries that one), so nothing on the page appears twice; with a single
  product the grid stays out of the way. A store with no products renders an intentional setting-up state rather than
  vanishing: a brand-new shop must never look broken to its first visitor, and
  the merchant previewing it is that first visitor.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Akwaaba.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "akwaaba/collection"
  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "New arrivals"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.grid_products != [] or @layout.count == 0}
      class="bg-white px-5 py-12 [font-family:var(--akwaaba-body)] sm:px-10 sm:py-16"
      aria-labelledby="akwaaba-collection-heading"
    >
      <div class="mx-auto max-w-[1320px]">
        <div class="flex flex-wrap items-end justify-between gap-4">
          <h2
            id="akwaaba-collection-heading"
            class="text-3xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)] sm:text-4xl"
          >
            {@settings["heading"] || "New arrivals"}
          </h2>

          <a
            :if={@layout.grid_products != []}
            href={store_path(@store.slug, "/products")}
            class="rounded-full border border-zinc-200 px-5 py-2.5 text-sm font-semibold text-[color:var(--akwaaba-ink)] hover:border-[color:var(--akwaaba-sun)] hover:text-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] motion-safe:transition-colors"
          >
            View all
          </a>
        </div>

        <div
          :if={@layout.grid_products != []}
          class="mt-8 grid grid-cols-2 gap-x-4 gap-y-8 lg:grid-cols-4"
        >
          <Shared.product_card
            :for={product <- Enum.take(@layout.grid_products, 8)}
            product={product}
            store={@store}
          />
        </div>

        <div
          :if={@layout.count == 0}
          class="mt-8 rounded-3xl border border-dashed border-zinc-200 bg-[#F6F4F1] px-6 py-16 text-center"
        >
          <p class="text-2xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
            The first pieces are on their way
          </p>
          <p class="mt-2 text-sm text-zinc-500">
            {@store.name} is setting up. Check back shortly.
          </p>
        </div>
      </div>
    </section>
    """
  end
end
