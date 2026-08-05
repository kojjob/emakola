defmodule Emakola.Themes.Adwuma.ProductList do
  @moduledoc """
  The shop listing.

  `show_add={true}`: `ProductListLive` does handle `add_to_cart`, delegating to
  `EmakolaWeb.Storefront.QuickAdd`. Category filters send
  `phx-value-category_id` — `ProductListLive` matches on that key and nothing
  else.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Adwuma.Shared

  def render(assigns) do
    assigns =
      assigns
      |> assign(:theme_module, Emakola.Themes.Adwuma)
      |> assign(:categories, Map.get(assigns, :categories) || [])

    ~H"""
    <div class="min-h-screen bg-[color:var(--adw-bg)] pb-16 text-[color:var(--adw-ink)] sm:pb-0">
      <Shared.theme_styles theme={@theme} />

      <a
        href="#adwuma-listing"
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-full focus:bg-[color:var(--adw-ink)] focus:px-5 focus:py-2 focus:text-sm focus:text-white"
      >
        Skip to content
      </a>

      <Shared.adwuma_nav
        store={@store}
        categories={@categories}
        cart_count={Map.get(assigns, :cart_count) || 0}
      />

      <main
        id="adwuma-listing"
        class="mx-auto max-w-6xl px-4 py-12 sm:px-6 [font-family:var(--adw-body)]"
      >
        <nav class="text-sm text-[color:var(--adw-muted)]" aria-label="Breadcrumb">
          <a href={store_path(@store.slug, "/")} class="hover:text-[color:var(--adw-ink)]">
            {@store.name}
          </a>
          <span aria-hidden="true">/</span>
          <span class="text-[color:var(--adw-ink)]">Shop</span>
        </nav>

        <h1 class="mt-4 text-3xl font-semibold tracking-tight text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
          Shop
        </h1>

        <div :if={@categories != []} class="mt-6 flex flex-wrap gap-2">
          <button
            type="button"
            phx-click="filter_category"
            phx-value-category_id="all"
            class="rounded-full border border-[color:var(--adw-rule)] px-4 py-1.5 text-sm text-[color:var(--adw-muted)] hover:border-[color:var(--adw-ink)] hover:text-[color:var(--adw-ink)]"
          >
            All
          </button>
          <button
            :for={category <- @categories}
            type="button"
            phx-click="filter_category"
            phx-value-category_id={category.id}
            class="rounded-full border border-[color:var(--adw-rule)] px-4 py-1.5 text-sm text-[color:var(--adw-muted)] hover:border-[color:var(--adw-ink)] hover:text-[color:var(--adw-ink)]"
          >
            {category.name}
          </button>
        </div>

        <div
          id="product-list"
          phx-update="stream"
          class="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-4"
        >
          <p
            id="product-list-empty"
            class="col-span-full hidden py-16 text-center text-[color:var(--adw-muted)] only:block"
          >
            Nothing here yet.
          </p>
          <div
            :for={{dom_id, %{product: product}} <- @streams.products}
            id={dom_id}
            class="contents"
          >
            <Shared.product_card product={product} store={@store} show_add={true} />
          </div>
        </div>

        <div :if={assigns[:has_more]} class="mt-12 text-center">
          <button
            type="button"
            phx-click="load_more"
            class="inline-flex min-h-11 items-center rounded-full border border-[color:var(--adw-ink)] px-8 text-sm font-medium text-[color:var(--adw-ink)] transition-colors hover:bg-[color:var(--adw-ink)] hover:text-white"
          >
            Load more
          </button>
        </div>
      </main>

      <Shared.footer store={@store} categories={@categories} />
      <Shared.bottom_nav store={@store} cart_count={Map.get(assigns, :cart_count) || 0} />
    </div>
    """
  end
end
