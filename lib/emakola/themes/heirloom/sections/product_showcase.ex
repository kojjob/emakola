defmodule Emakola.Themes.Heirloom.Sections.ProductShowcase do
  @moduledoc """
  The store's products as a row of tiles, under its category names.

  The reference put superscript counts on each category tab
  (`Living room¹²`) and made them filter in place. Neither is reproduced
  literally:

  - the counts are omitted, for the reason given in `CategoryGallery` — the
    home page holds eight products, so a count taken from them is the page
    size and not the category's
  - the tabs are links to each category's own page rather than a client-side
    filter. `StoreLive` handles `search_overlay`, `add_to_cart` and
    `close_search` and nothing else, so a `filter_category` click here would
    hit no clause and crash the page — storefront LiveViews have no
    catch-all `handle_event/3`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Heirloom.ProductList

  @default_limit 5

  @impl true
  def key, do: "heirloom/product_showcase"

  @impl true
  def label, do: "Products"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "limit", type: :integer, label: "Products shown", default: @default_limit}
    ]
  end

  @impl true
  def render(assigns) do
    products = Map.get(assigns, :products) || []
    categories = Map.get(assigns, :categories) || []

    assigns =
      assigns
      |> assign(:showcase, Enum.take(products, limit(assigns.settings["limit"])))
      |> assign(:tabs, Enum.take(categories, 4))
      |> assign(:heading, present(assigns.settings["heading"]))

    ~H"""
    <section :if={@showcase != []} class="bg-[color:var(--hl-bg)] pb-24 sm:pb-32">
      <div class="mx-auto max-w-[1360px] px-5 sm:px-8">
        <div class="flex flex-wrap items-end justify-between gap-6">
          <div class="flex flex-wrap items-baseline gap-x-6 gap-y-2">
            <h2
              :if={@heading}
              class="text-3xl font-light tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)] sm:text-4xl"
            >
              {@heading}
            </h2>
            <a
              :for={category <- @tabs}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="text-2xl font-light tracking-tight text-[color:var(--hl-muted)] [font-family:var(--hl-display)] hover:text-[color:var(--hl-ink)] motion-safe:transition-colors sm:text-3xl"
            >
              {category.name}
            </a>
          </div>

          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex min-h-[44px] items-center rounded-full bg-[color:var(--hl-ink)] px-6 text-[11px] font-semibold uppercase tracking-[0.16em] text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)] focus-visible:ring-offset-2"
          >
            All products
          </a>
        </div>

        <ul class="mt-10 grid grid-cols-2 gap-x-4 gap-y-10 lg:grid-cols-5 lg:gap-x-5">
          <li :for={product <- @showcase}>
            <ProductList.tile product={product} store={@store} />
          </li>
        </ul>
      </div>
    </section>
    """
  end

  defp limit(value) when is_integer(value) and value > 0, do: value

  defp limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed > 0 -> parsed
      _unparseable -> @default_limit
    end
  end

  defp limit(_other), do: @default_limit

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(_other), do: nil
end
