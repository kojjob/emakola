defmodule Emakola.Themes.Heirloom.ProductList do
  @moduledoc """
  Heirloom shop — category filter, then a grid of tiles.

  Every `phx-click` names an event `EmakolaWeb.Storefront.ProductListLive`
  actually handles: `filter_category` (`category_id`), `add_to_cart`
  (`product-id`), `load_more`. Inventing a fourth would crash the page,
  since storefront LiveViews have no catch-all `handle_event/3`.

  Category counts are omitted here on purpose. The reference showed
  `Living room¹²`, but this page holds only the current filtered page of
  products, so any count rendered from it would be the page size rather
  than the category total — a number that looks authoritative and is wrong.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Heirloom.Shared

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Heirloom)
      |> assign(:categories, assigns[:categories] || [])
      |> assign(:products, assigns[:products] || [])

    ~H"""
    <div class="min-h-screen bg-[color:var(--hl-bg)] [font-family:var(--hl-font)]">
      <Shared.theme_styles theme={@theme} />
      <Shared.heirloom_nav store={@store} cart_count={assigns[:cart_count] || 0} on_dark={false} />

      <main class="mx-auto max-w-[1360px] px-5 pb-24 pt-12 sm:px-8">
        <h1 class="text-4xl font-light tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)] sm:text-5xl">
          The collection
        </h1>

        <div :if={@categories != []} class="mt-10 flex flex-wrap gap-2">
          <button
            type="button"
            phx-click="filter_category"
            phx-value-category_id="all"
            class={filter_class(assigns[:selected_category] in [nil, "all"])}
          >
            All
          </button>
          <button
            :for={category <- @categories}
            type="button"
            phx-click="filter_category"
            phx-value-category_id={category.id}
            class={filter_class(assigns[:selected_category] == category.id)}
          >
            {category.name}
          </button>
        </div>

        <p
          :if={@products == []}
          class="mt-16 rounded-[28px] border border-[color:var(--hl-border)] bg-white p-12 text-center text-sm text-[color:var(--hl-muted)]"
        >
          Nothing here yet. Check back soon.
        </p>

        <ul
          :if={@products != []}
          class="mt-10 grid grid-cols-2 gap-x-4 gap-y-10 lg:grid-cols-4 lg:gap-x-6"
        >
          <li :for={product <- @products}>
            <.tile product={product} store={@store} />
          </li>
        </ul>

        <div :if={assigns[:has_more]} class="mt-14 text-center">
          <button
            type="button"
            phx-click="load_more"
            class="inline-flex min-h-[52px] items-center rounded-full border border-[color:var(--hl-ink)] px-10 text-[11px] font-semibold uppercase tracking-[0.16em] text-[color:var(--hl-ink)] hover:bg-[color:var(--hl-ink)] hover:text-white motion-safe:transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)]"
          >
            Load more
          </button>
        </div>
      </main>
    </div>

    <Shared.footer store={@store} categories={@categories} />
    """
  end

  attr :product, :map, required: true
  attr :store, :map, required: true

  @doc """
  One product tile.

  The sale badge is driven by the variant's real `compare_at_price`. The
  reference showed a "1 WEEK" lead-time pill here; that would be a delivery
  promise the merchant never made, so it is a genuine discount marker instead.
  """
  def tile(assigns) do
    assigns =
      assigns
      |> assign(:price, Shared.price_label(assigns.product, assigns.store))
      |> assign(:compare, Shared.compare_at_label(assigns.product, assigns.store))
      |> assign(:thumb, thumb(assigns.product))

    ~H"""
    <a
      href={store_path(@store.slug, "/products/#{@product.slug}")}
      class="group block focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)] focus-visible:ring-offset-4"
    >
      <div class="relative aspect-square overflow-hidden rounded-[28px] bg-[color:var(--hl-tile)]">
        <span
          :if={@compare}
          class="absolute left-3 top-3 z-10 rounded-full bg-[color:var(--hl-accent)] px-3 py-1 text-[10px] font-bold uppercase tracking-[0.12em] text-white"
        >
          Sale
        </span>
        <.optimized_image
          src={@thumb}
          alt={@product.title}
          width={600}
          height={600}
          class="h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-500 group-hover:scale-[1.04]"
        />
      </div>
      <p class="mt-4 text-base text-[color:var(--hl-ink)] [font-family:var(--hl-display)]">
        {@product.title}
      </p>
      <p class="mt-1 flex items-baseline gap-2">
        <span :if={@price} class="text-sm font-semibold tabular-nums text-[color:var(--hl-ink)]">
          {@price}
        </span>
        <s :if={@compare} class="text-xs text-[color:var(--hl-muted)]">
          <span class="sr-only">was</span>{@compare}
        </s>
      </p>
    </a>
    """
  end

  defp filter_class(active?) do
    [
      "min-h-[44px] rounded-full border px-6 text-[11px] font-semibold uppercase tracking-[0.14em] motion-safe:transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)]",
      if(active?,
        do: "border-[color:var(--hl-ink)] bg-[color:var(--hl-ink)] text-white",
        else:
          "border-[color:var(--hl-border)] bg-white text-[color:var(--hl-ink)] hover:border-[color:var(--hl-ink)]"
      )
    ]
  end

  defp thumb(product) do
    case Map.get(product, :images) do
      [_ | _] = images ->
        image = images |> Enum.sort_by(& &1.position) |> List.first()
        image.thumbnail_url || image.url

      _none ->
        nil
    end
  end
end
