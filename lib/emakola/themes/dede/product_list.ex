defmodule Emakola.Themes.Dede.ProductList do
  @moduledoc """
  Dede theme — the full menu page.

  A single-column board even on desktop: menus are read top to bottom, not
  browsed as a catalogue. Search and category chips bind to the
  ProductListLive handlers (`search`, `filter_category`, `load_more`);
  every dish row carries a one-tap add and its availability.
  """
  use Phoenix.Component

  alias Emakola.Themes.Dede.Shared

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAF5EA]">
      <Shared.dede_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <div class="mx-auto max-w-[880px] px-4 pt-6 sm:px-6 sm:pt-8 lg:px-8">
        <h1
          id="dede-list-heading"
          class="text-4xl uppercase leading-none tracking-wide text-[#26211A] [font-family:var(--dt-heading-font,'Anton',sans-serif)] sm:text-5xl"
        >
          Menu
        </h1>
        <p :if={@products_count > 0} class="mt-2 text-sm text-[#6B6355]">
          {@products_count} {if @products_count == 1, do: "dish", else: "dishes"} on the board
        </p>

        <form phx-change="search" class="mt-5">
          <label for="dede-menu-search" class="sr-only">Search the menu</label>
          <div class="relative">
            <svg
              class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-[#6B6355]"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.8"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
              />
            </svg>
            <input
              id="dede-menu-search"
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search the menu..."
              phx-debounce="300"
              class="min-h-12 w-full rounded-full border-2 border-[#26211A]/15 bg-white py-3 pl-11 pr-5 text-sm text-[#26211A] placeholder-[#6B6355] hover:border-[#26211A]/30 focus:border-[#26211A] focus:outline-none focus:ring-2 focus:ring-[#26211A]/15 motion-safe:transition-colors"
            />
          </div>
        </form>

        <div
          :if={@categories != []}
          class="mt-4 flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
        >
          <button
            type="button"
            phx-click="filter_category"
            phx-value-category_id="all"
            class={[
              "inline-flex min-h-11 flex-shrink-0 cursor-pointer items-center whitespace-nowrap rounded-full border-2 px-5 text-sm font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-colors",
              if(is_nil(@selected_category),
                do: "border-[#1B2E23] bg-[#1B2E23] text-[#F3EDDF]",
                else: "border-[#26211A]/20 bg-white text-[#26211A] hover:border-[#26211A]"
              )
            ]}
          >
            Everything
          </button>
          <button
            :for={category <- @categories}
            type="button"
            phx-click="filter_category"
            phx-value-category_id={category.id}
            class={[
              "inline-flex min-h-11 flex-shrink-0 cursor-pointer items-center whitespace-nowrap rounded-full border-2 px-5 text-sm font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-colors",
              if(@selected_category == category.id,
                do: "border-[#1B2E23] bg-[#1B2E23] text-[#F3EDDF]",
                else: "border-[#26211A]/20 bg-white text-[#26211A] hover:border-[#26211A]"
              )
            ]}
          >
            {category.name}
          </button>
        </div>
      </div>

      <div class="mx-auto max-w-[880px] px-4 py-5 sm:px-6 sm:py-6 lg:px-8">
        <div class="rounded-2xl bg-[#1B2E23] px-5 py-4 ring-1 ring-inset ring-white/10 sm:px-8 sm:py-6">
          <ul id="product-list" phx-update="stream" role="list" class="divide-y divide-white/10">
            <li id="product-list-empty" class="hidden py-12 text-center only:block">
              <p class="text-xl uppercase tracking-wide text-[#F3EDDF]/90 [font-family:var(--dt-heading-font,'Anton',sans-serif)]">
                {if @search_query != "" || @selected_category,
                  do: "Nothing on the board matches",
                  else: "The board is still being chalked up"}
              </p>
              <p class="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-[#A8BAA5]">
                {if @search_query != "" || @selected_category,
                  do: "Try another dish, or see everything on the board.",
                  else: "#{@store.name} hasn't written up the menu yet — check back soon."}
              </p>
              <button
                :if={@search_query != "" || @selected_category}
                type="button"
                phx-click="filter_category"
                phx-value-category_id="all"
                class="mt-5 inline-flex min-h-11 cursor-pointer items-center rounded-full bg-[#F3EDDF] px-6 text-sm font-bold text-[#1B2E23] hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF] focus-visible:ring-offset-2 focus-visible:ring-offset-[#1B2E23] motion-safe:transition-colors"
              >
                Show the whole menu
              </button>
            </li>
            <Shared.menu_row
              :for={{dom_id, %{product: product}} <- @streams.products}
              id={dom_id}
              product={product}
              store={@store}
            />
          </ul>
        </div>

        <div :if={@has_more} class="mt-6 text-center">
          <button
            type="button"
            phx-click="load_more"
            class="inline-flex min-h-12 cursor-pointer items-center gap-2 rounded-full border-2 border-[#26211A]/25 bg-white px-8 text-sm font-bold text-[#26211A] hover:border-[#26211A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#26211A] focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            More from the kitchen
          </button>
        </div>
      </div>

      <Shared.footer store={@store} categories={@categories} />
      <Shared.dede_bottom_nav store={@store} cart_count={@cart_count} />
    </div>
    """
  end
end
