defmodule Emakola.Themes.Dede.Sections.Menu do
  @moduledoc """
  The menu board — Dede's signature section and its one aesthetic risk.

  Instead of a photo-card catalogue grid, dishes render as rows on a
  bottle-green board: name in signboard type, dotted leader, price in
  tabular numerals, one-tap add. The board is complete before a single
  image byte arrives — on 2G the menu IS the design and the photo is
  garnish. Sold-out dishes stay chalked on the board, struck through and
  stamped, because "finished for today" is information, not absence.

  A store with zero products renders an intentional being-chalked-up state
  — a brand-new chop bar must never look broken to its first visitor.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Dede.Shared

  @impl true
  def key, do: "dede/menu"
  @impl true
  def label, do: "Menu board"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: "Menu"},
      %{key: "note", type: :string, label: "Board note", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      id="dede-menu"
      class="px-4 py-4 sm:px-6 sm:py-6 lg:px-8"
      aria-labelledby="dede-menu-heading"
    >
      <div class="mx-auto max-w-[880px] rounded-2xl bg-[#1B2E23] px-5 py-6 ring-1 ring-inset ring-white/10 sm:px-8 sm:py-8">
        <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 border-b-2 border-[#F3EDDF]/15 pb-4">
          <h2
            id="dede-menu-heading"
            class="text-2xl uppercase tracking-wide text-[#F3EDDF] [font-family:var(--dt-heading-font,'Anton',sans-serif)]"
          >
            {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Menu"}
          </h2>
          <p :if={@settings["note"] not in [nil, ""]} class="text-xs italic text-[#A8BAA5]">
            {@settings["note"]}
          </p>
        </div>

        <ul :if={@products != []} role="list" class="divide-y divide-white/10">
          <%!-- quick_add: the home page is StoreLive, whose add_to_cart
          handler takes the product-id payload. --%>
          <Shared.menu_row
            :for={product <- @products}
            product={product}
            store={@store}
            quick_add={true}
          />
        </ul>

        <div :if={@products == []} class="py-12 text-center">
          <p class="text-xl uppercase tracking-wide text-[#F3EDDF]/90 [font-family:var(--dt-heading-font,'Anton',sans-serif)]">
            The board is still being chalked up
          </p>
          <p class="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-[#A8BAA5]">
            {@store.name} hasn't written up the menu yet — check back soon.
          </p>
        </div>

        <div :if={@products != []} class="mt-5 text-center">
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex min-h-11 items-center rounded text-sm font-semibold text-[#F3EDDF] underline decoration-[#F3EDDF]/40 underline-offset-4 hover:decoration-[#F3EDDF] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF] motion-safe:transition-colors"
          >
            See the full menu
          </a>
        </div>
      </div>
    </section>
    """
  end
end
