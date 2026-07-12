defmodule Emakola.Themes.Chale.ProductList do
  @moduledoc """
  Chale theme — product list page renderer.

  Poster header ("Shop all" at display scale), live search, category
  filter tags, the pasted-flyer product grid, and load-more pagination.
  Cards carry NO quick add-to-cart here: `ProductListLive` has no
  `add_to_cart` handler, so a binding would crash the live page.
  """
  use Phoenix.Component

  alias Emakola.Themes.Chale.Shared

  def render(assigns) do
    ~H"""
    <Shared.theme_styles theme={@theme} />
    <%!-- Theme banner nav: the bottom bar below is mobile-only, so without
    this the cart would be unreachable from the list page on desktop. --%>
    <Shared.chale_nav store={@store} categories={@categories} cart_count={@cart_count} />

    <div class="border-b-2 border-zinc-950 bg-zinc-100">
      <div class="mx-auto max-w-[1280px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <h1 class="text-5xl font-bold uppercase leading-[0.95] tracking-tight text-zinc-950 [font-family:var(--chale-display)] sm:text-7xl">
          Shop all
        </h1>
        <p class="mt-3 text-sm font-medium text-zinc-600">
          <span class="inline-flex items-center border-2 border-zinc-950 bg-white px-2.5 py-1 text-[0.6875rem] font-bold uppercase tracking-widest text-zinc-950">
            {length(@products)} items
          </span>
        </p>
      </div>
    </div>

    <div class="mx-auto max-w-[1280px] px-4 pb-24 pt-6 sm:px-6 sm:pt-8 lg:px-8">
      <div class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <%!-- Category filter tags --%>
        <div class="flex items-center gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          <button
            type="button"
            phx-click="filter_category"
            phx-value-category_id="all"
            class={[
              "flex-shrink-0 cursor-pointer border-2 border-zinc-950 px-4 py-2 text-xs font-bold uppercase tracking-widest focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors",
              if(is_nil(@selected_category),
                do: "bg-zinc-950 text-white",
                else: "bg-white text-zinc-950 hover:bg-zinc-100"
              )
            ]}
          >
            All
          </button>
          <button
            :for={category <- @categories}
            type="button"
            phx-click="filter_category"
            phx-value-category_id={category.id}
            class={[
              "flex-shrink-0 cursor-pointer border-2 border-zinc-950 px-4 py-2 text-xs font-bold uppercase tracking-widest focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors",
              if(@selected_category == category.id,
                do: "bg-zinc-950 text-white",
                else: "bg-white text-zinc-950 hover:bg-zinc-100"
              )
            ]}
          >
            {category.name}
          </button>
        </div>

        <%!-- Search --%>
        <form phx-change="search" class="w-full lg:max-w-xs">
          <label for="chale-list-search" class="sr-only">Search products</label>
          <input
            id="chale-list-search"
            type="text"
            name="query"
            value={@search_query}
            placeholder="Search the rack..."
            phx-debounce="300"
            class="w-full border-2 border-zinc-950 bg-white px-4 py-2.5 text-sm text-zinc-950 placeholder-zinc-400 focus:outline-none focus:ring-2 focus:ring-store-accent"
          />
        </form>
      </div>

      <%= if @products == [] do %>
        <div class="border-2 border-dashed border-zinc-400 bg-white px-6 py-16 text-center sm:py-20">
          <h2 class="text-2xl font-bold uppercase tracking-tight text-zinc-950 [font-family:var(--chale-display)] sm:text-3xl">
            Nothing here, chale
          </h2>
          <p class="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-zinc-600">
            No products match your search — try another word or browse everything.
          </p>
          <button
            :if={@search_query != "" || @selected_category}
            type="button"
            phx-click="filter_category"
            phx-value-category_id="all"
            class="mt-6 inline-flex cursor-pointer items-center border-2 border-zinc-950 bg-white px-6 py-2.5 text-xs font-bold uppercase tracking-widest text-zinc-950 hover:bg-zinc-950 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            Clear all filters
          </button>
        </div>
      <% else %>
        <div class="grid grid-cols-2 gap-4 sm:gap-5 md:grid-cols-3 lg:grid-cols-4 lg:gap-6">
          <Shared.product_card :for={product <- @products} product={product} store={@store} />
        </div>

        <div :if={@has_more} class="mt-10 text-center">
          <button
            type="button"
            phx-click="load_more"
            class="inline-flex cursor-pointer items-center gap-2 border-2 border-zinc-950 bg-white px-8 py-3 text-xs font-bold uppercase tracking-widest text-zinc-950 shadow-[4px_4px_0_0_#09090B] hover:bg-zinc-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-950 focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:translate-y-0.5"
          >
            Load more
            <svg
              class="h-4 w-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19.5 13.5L12 21m0 0l-7.5-7.5M12 21V3"
              />
            </svg>
          </button>
        </div>
      <% end %>
    </div>

    <Shared.footer store={@store} categories={@categories} theme={@theme} />
    <Shared.chale_bottom_nav store={@store} cart_count={@cart_count} active={:shop} />
    """
  end
end
