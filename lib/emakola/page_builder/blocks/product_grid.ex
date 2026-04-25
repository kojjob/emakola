defmodule Emakola.PageBuilder.Blocks.ProductGrid do
  @moduledoc """
  Showcase a responsive grid of products. Source can be `featured` (use the
  pre-loaded products from `StoreLive`), `category:<slug>` (filter by
  category — Phase 2 query support), or `manual:<id1,id2>` (specific IDs —
  Phase 2 query support). Phase 1 honors `featured` and falls back to all
  passed-in products for the other sources.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `title` | string \\| nil | "Featured products" |
  | `source` | string | "featured" |
  | `count` | integer | 8 |
  | `columns` | 2 \\| 3 \\| 4 | 4 |
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  @impl true
  def type, do: "product_grid"

  @impl true
  def name, do: "Product Grid"

  @impl true
  def icon, do: "grid_view"

  @impl true
  def default_content do
    %{
      title: "Featured products",
      source: "featured",
      count: 8,
      columns: 4
    }
  end

  @impl true
  def render(assigns) do
    products =
      assigns.products
      |> products_for_source(assigns.content[:source])
      |> Enum.take(assigns.content[:count] || 8)

    assigns =
      assigns
      |> assign(:products_to_show, products)
      |> assign(:grid_class, grid_class(assigns.content[:columns]))

    ~H"""
    <section :if={@products_to_show != []} class="py-10 sm:py-14 bg-[#FFFBEB]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <h2
          :if={@content[:title]}
          class="text-2xl sm:text-3xl font-bold text-[#1C1917] mb-6 sm:mb-8"
          style="font-family: 'Manrope', sans-serif;"
        >
          {@content[:title]}
        </h2>
        <div class={["grid gap-4 sm:gap-5 lg:gap-6", @grid_class]}>
          <a
            :for={product <- @products_to_show}
            href={"/s/#{@store.slug}/products/#{product.slug}"}
            class="group block"
          >
            <div class="relative rounded-2xl overflow-hidden mb-3 bg-[#FEF3C7]/40 aspect-[3/4]">
              <%= if product_image(product) do %>
                <.optimized_image
                  src={product_image(product)}
                  alt={product.title}
                  class="w-full h-full object-cover group-hover:scale-[1.04] transition-transform duration-500"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center bg-[#FEF3C7]">
                  <span class="material-symbols-outlined text-4xl text-[#D97706]">
                    shopping_bag
                  </span>
                </div>
              <% end %>
            </div>
            <p
              class="text-sm font-semibold text-[#1C1917] truncate"
              style="font-family: 'Inter', sans-serif;"
            >
              {product.title}
            </p>
            <p class="text-sm font-bold text-[#B45309] tabular-nums">
              {Currency.format_price_range(product.min_price, product.max_price, @store.currency)}
            </p>
          </a>
        </div>
      </div>
    </section>
    """
  end

  @impl true
  def edit_form(assigns) do
    ~H"""
    <p class="text-sm text-[#78716C]">
      Edit form coming in Phase 2 of the page builder.
    </p>
    """
  end

  defp products_for_source(products, "featured"), do: products

  defp products_for_source(products, _other) do
    # Phase 2: implement category:<slug> and manual:<ids> filters with a
    # dedicated Catalog query. For Phase 1, fall back to the passed-in list
    # so a misconfigured block still renders something sensible.
    products
  end

  defp grid_class(2), do: "grid-cols-2"
  defp grid_class(3), do: "grid-cols-2 md:grid-cols-3"
  defp grid_class(4), do: "grid-cols-2 md:grid-cols-3 lg:grid-cols-4"
  defp grid_class(_), do: "grid-cols-2 md:grid-cols-3 lg:grid-cols-4"

  defp product_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end
end
