defmodule Emakola.Themes.Pace.ProductList do
  @moduledoc """
  Pace theme — product list page.

  The ice ground and rounded canvas carry over from the home page:
  breadcrumb, kinetic page header, search (debounced `search` handler),
  category lane filters (`filter_category`), the night-card grid, and
  `load_more` pagination. Empty results render a deliberate state with a
  way back, never a blank canvas.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Pace.Components
  alias Emakola.Themes.Pace.Shared

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[var(--theme-bg,#E6EFF6)] pt-2">
      <Shared.theme_styles theme={@theme} />
      <Shared.pace_nav
        store={@store}
        categories={@categories}
        cart_count={assigns[:cart_count] || 0}
      />

      <div class="px-2 pt-3 sm:px-4 lg:px-6">
        <div class="mx-auto max-w-[1440px] rounded-[28px] bg-white pb-16 sm:rounded-[36px]">
          <div class="mx-auto max-w-[1280px] px-5 sm:px-8 lg:px-10">
            <nav aria-label="Breadcrumb" class="pt-6">
              <ol class="flex items-center gap-2 text-xs font-medium tracking-wide text-slate-500">
                <li>
                  <a
                    href={store_path(@store.slug, "/")}
                    class="rounded hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 motion-safe:transition-colors"
                  >
                    Home
                  </a>
                </li>
                <li aria-hidden="true" class="pace-display italic text-slate-300">///</li>
                <li class="text-slate-950">Shop</li>
              </ol>
            </nav>

            <div class="py-6 sm:py-8">
              <h1 class="pace-display text-4xl font-bold uppercase italic tracking-tight text-slate-950 sm:text-5xl">
                Shop all
              </h1>
              <p class="mt-3 text-sm text-slate-600 sm:text-base">
                {length(@products)} {if length(@products) == 1, do: "item", else: "items"} in the lineup
              </p>
            </div>

            <div class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div class="flex items-center gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
                <button
                  phx-click="filter_category"
                  phx-value-category_id="all"
                  class={[
                    "h-11 flex-shrink-0 cursor-pointer whitespace-nowrap rounded-full border px-5 text-xs font-bold uppercase tracking-[0.12em] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
                    if(is_nil(@selected_category),
                      do: "border-slate-950 bg-slate-950 text-white",
                      else:
                        "border-slate-200 bg-white text-slate-700 hover:border-slate-950 hover:text-slate-950"
                    )
                  ]}
                >
                  All
                </button>
                <button
                  :for={cat <- @categories}
                  phx-click="filter_category"
                  phx-value-category_id={cat.id}
                  class={[
                    "h-11 flex-shrink-0 cursor-pointer whitespace-nowrap rounded-full border px-5 text-xs font-bold uppercase tracking-[0.12em] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors",
                    if(@selected_category == cat.id,
                      do: "border-slate-950 bg-slate-950 text-white",
                      else:
                        "border-slate-200 bg-white text-slate-700 hover:border-slate-950 hover:text-slate-950"
                    )
                  ]}
                >
                  {cat.name}
                </button>
              </div>

              <form phx-change="search" class="w-full lg:max-w-xs">
                <label for="pace-list-search" class="sr-only">Search products</label>
                <div class="relative">
                  <svg
                    class="absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
                    />
                  </svg>
                  <input
                    id="pace-list-search"
                    type="text"
                    name="query"
                    value={@search_query}
                    placeholder="Search gear..."
                    phx-debounce="300"
                    class="min-h-[44px] w-full rounded-full border border-slate-200 bg-white pl-11 pr-4 text-sm text-slate-950 placeholder-slate-400 focus:border-slate-950 focus:outline-none focus:ring-2 focus:ring-slate-900/10"
                  />
                </div>
              </form>
            </div>

            <%= if @products == [] do %>
              <div class="rounded-[24px] border-2 border-dashed border-slate-200 bg-[#F1F6FA] px-6 py-20 text-center">
                <h2 class="pace-display mb-1.5 text-xl font-bold uppercase italic tracking-tight text-slate-950">
                  No gear found
                </h2>
                <p class="mx-auto mb-6 max-w-sm text-sm leading-relaxed text-slate-600">
                  Nothing matches that search. Try another word or browse the full lineup.
                </p>
                <button
                  :if={@search_query != "" || @selected_category}
                  phx-click="filter_category"
                  phx-value-category_id="all"
                  class="inline-flex min-h-[44px] cursor-pointer items-center rounded-full bg-slate-950 px-6 text-sm font-semibold text-white hover:bg-slate-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
                >
                  Clear all filters
                </button>
              </div>
            <% else %>
              <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 xl:grid-cols-4 xl:gap-5">
                <Components.product_card :for={product <- @products} product={product} store={@store} />
              </div>

              <div :if={@has_more} class="mt-10 text-center">
                <button
                  phx-click="load_more"
                  class="inline-flex min-h-[48px] cursor-pointer items-center gap-2 rounded-full border border-slate-200 bg-white px-8 text-sm font-semibold text-slate-950 hover:border-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
                >
                  Load more <span class="pace-display text-xs italic" aria-hidden="true">///</span>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <Shared.footer store={@store} categories={@categories} theme={assigns[:theme] || %{}} />
    </div>

    <Shared.pace_bottom_nav store={@store} active_tab={:search} cart_count={@cart_count} />
    """
  end
end
