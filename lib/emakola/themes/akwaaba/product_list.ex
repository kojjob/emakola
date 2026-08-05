defmodule Emakola.Themes.Akwaaba.ProductList do
  @moduledoc """
  Akwaaba product list — the shop.

  Cards are browse-only (`show_add={false}`): this LiveView has no `add_to_cart`
  handler, and a `phx-click` naming an event nobody handles crashes the page
  rather than doing nothing.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Akwaaba.Shared

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Akwaaba)

    ~H"""
    <div class="min-h-screen bg-white [font-family:var(--akwaaba-body)]">
      <Shared.theme_styles theme={@theme} />
      <a
        href="#akwaaba-content"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-[color:var(--akwaaba-ink)] focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>

      <Shared.akwaaba_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />

      <main id="akwaaba-content" class="mx-auto max-w-[1320px] px-5 pb-24 pt-10 sm:px-10">
        <nav
          aria-label="Breadcrumb"
          class="text-xs font-medium uppercase tracking-[0.2em] text-zinc-400"
        >
          <a
            href={store_path(@store.slug, "/")}
            class="hover:text-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)]"
          >
            Shop
          </a>
          <span aria-hidden="true" class="mx-2">/</span>
          <span class="text-[color:var(--akwaaba-ink)]">{@page_title || "All products"}</span>
        </nav>

        <h1 class="mt-4 text-4xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)] sm:text-5xl">
          {@page_title || "All products"}
        </h1>

        <p class="mt-3 text-sm text-zinc-500">
          {@products_count} {if @products_count == 1, do: "piece", else: "pieces"}
        </p>

        <div
          id="product-list"
          phx-update="stream"
          class="mt-10 grid grid-cols-2 gap-x-4 gap-y-8 lg:grid-cols-4"
        >
          <div
            id="product-list-empty"
            class="col-span-full hidden rounded-3xl border border-dashed border-zinc-200 bg-[#F6F4F1] px-6 py-16 text-center only:block"
          >
            <p class="text-2xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
              Nothing here yet
            </p>
            <p class="mt-2 text-sm text-zinc-500">Try another category, or come back shortly.</p>
          </div>
          <div
            :for={{dom_id, %{product: product}} <- @streams.products}
            id={dom_id}
            class="contents"
          >
            <Shared.product_card product={product} store={@store} show_add={false} />
          </div>
        </div>

        <div :if={assigns[:has_more]} class="mt-12 text-center">
          <button
            type="button"
            phx-click="load_more"
            class="inline-flex min-h-12 items-center rounded-full bg-[color:var(--akwaaba-ink)] px-8 text-sm font-semibold text-white transition-colors hover:bg-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)] focus-visible:ring-offset-2"
          >
            Load more
          </button>
        </div>
      </main>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.bottom_nav store={@store} cart_count={assigns[:cart_count] || 0} active={:shop} />
    """
  end
end
