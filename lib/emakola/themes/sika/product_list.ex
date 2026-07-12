defmodule Emakola.Themes.Sika.ProductList do
  @moduledoc """
  Sika theme — the collection page.

  A calm, centred page: one h1, the caught-light rule, quiet category
  stamps and search on one hairline band, and a two-column vitrine of
  large framed cards — never a dense thumbnail wall. No quick-add;
  every card is a doorway to the piece.
  """
  use Phoenix.Component

  alias Emakola.Themes.Sika.Shared

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAF9F7] text-[#211D16] [font-family:var(--dt-body-font,Work_Sans,system-ui,sans-serif)]">
      <Shared.sika_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <div class="mx-auto max-w-[1200px] px-4 pb-24 sm:px-6 lg:px-8">
        <header class="py-12 text-center sm:py-16">
          <p class="text-[0.6875rem] font-semibold uppercase tracking-[0.25em] text-[#6E675C]">
            {@store.name}
          </p>
          <h1 class="mt-3 text-4xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)] sm:text-5xl">
            The collection
          </h1>
          <Shared.caught_light class="mx-auto mt-5 w-16" />
          <p class="mt-4 text-sm tabular-nums text-[#6E675C]">{piece_count(@products)}</p>
        </header>

        <div class="flex flex-col gap-5 border-y border-[#E8E3D9] py-5 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex flex-wrap items-center gap-2" role="group" aria-label="Filter by category">
            <button
              phx-click="filter_category"
              phx-value-category_id="all"
              class={filter_classes(is_nil(@selected_category))}
            >
              All
            </button>
            <button
              :for={category <- @categories}
              phx-click="filter_category"
              phx-value-category_id={category.id}
              class={filter_classes(@selected_category == category.id)}
            >
              {category.name}
            </button>
          </div>
          <form phx-change="search" class="sm:w-64">
            <label for="sika-search" class="sr-only">Search the collection</label>
            <input
              id="sika-search"
              type="text"
              name="query"
              value={@search_query}
              phx-debounce="300"
              placeholder="Search the collection"
              class="w-full border border-[#E8E3D9] bg-white px-4 py-2.5 text-sm text-[#211D16] placeholder-[#A29B8C] focus:border-[#211D16] focus:outline-none focus:ring-1 focus:ring-[#211D16]"
            />
          </form>
        </div>

        <%= if @products == [] do %>
          <div class="mt-12 border border-[#E8E3D9] bg-white px-6 py-16 text-center sm:py-20">
            <span
              class="mx-auto flex h-16 w-16 items-center justify-center rounded-full border border-[#C2A15B]/50 text-2xl text-[#1F332C] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)] select-none"
              aria-hidden="true"
            >
              {String.first(@store.name)}
            </span>
            <%= if @search_query != "" || @selected_category do %>
              <h2 class="mt-5 text-xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]">
                No pieces match
              </h2>
              <p class="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-[#6E675C]">
                Nothing in the collection matches your search.
              </p>
              <button
                phx-click="filter_category"
                phx-value-category_id="all"
                class="mt-6 inline-flex cursor-pointer items-center border border-[#211D16] px-7 py-3 text-[0.75rem] font-semibold uppercase tracking-[0.2em] text-[#211D16] hover:bg-[#211D16] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-colors"
              >
                Clear filters
              </button>
            <% else %>
              <h2 class="mt-5 text-xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]">
                The vitrine is being arranged
              </h2>
              <p class="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-[#6E675C]">
                {@store.name} hasn't added any pieces yet — return soon.
              </p>
            <% end %>
          </div>
        <% else %>
          <div class="mt-12 grid grid-cols-1 gap-x-8 gap-y-14 sm:grid-cols-2">
            <Shared.piece_card :for={product <- @products} product={product} store={@store} />
          </div>

          <div :if={@has_more} class="mt-14 text-center">
            <button
              phx-click="load_more"
              class="inline-flex cursor-pointer items-center border border-[#211D16] px-8 py-3.5 text-[0.75rem] font-semibold uppercase tracking-[0.2em] text-[#211D16] hover:bg-[#211D16] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              Show more pieces
            </button>
          </div>
        <% end %>
      </div>

      <div class="h-16 sm:hidden" aria-hidden="true"></div>
    </div>

    <Shared.footer store={@store} categories={@categories} />
    <Shared.sika_bottom_nav store={@store} cart_count={@cart_count} active={:collection} />
    """
  end

  defp piece_count(products) do
    case length(products) do
      1 -> "1 piece"
      n -> "#{n} pieces"
    end
  end

  defp filter_classes(selected?) do
    base =
      "inline-flex cursor-pointer items-center px-3.5 py-2 text-[0.6875rem] font-semibold " <>
        "uppercase tracking-[0.18em] focus-visible:outline-none focus-visible:ring-2 " <>
        "focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-colors "

    if selected? do
      base <> "border border-[#1F332C] bg-[#1F332C] text-white"
    else
      base <>
        "border border-[#E8E3D9] bg-white text-[#6E675C] hover:border-[#211D16] hover:text-[#211D16]"
    end
  end
end
