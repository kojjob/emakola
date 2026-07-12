defmodule Emakola.Themes.Chale.Sections.Grid do
  @moduledoc """
  Chale home product grid — 2 / 3 / 4 columns of square pasted-flyer
  cards with quick add-to-cart (the home LiveView handles `add_to_cart`).

  A store with zero products renders an intentional setting-up state
  instead of nothing — a brand-new store must never look broken to its
  first visitor (or to the merchant previewing it).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Chale.Shared

  @impl true
  def key, do: "chale/grid"
  @impl true
  def label, do: "Product grid"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Shop all"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@products != []}
      class="px-4 py-6 sm:px-6 sm:py-8 lg:px-8"
      aria-labelledby="chale-grid-heading"
    >
      <div class="mx-auto max-w-[1280px]">
        <h2
          id="chale-grid-heading"
          class="mb-5 text-2xl font-bold uppercase tracking-tight text-[#101114] [font-family:var(--chale-display)] sm:text-3xl"
        >
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Shop all"}
        </h2>
        <div class="grid grid-cols-2 gap-4 sm:gap-5 md:grid-cols-3 lg:grid-cols-4 lg:gap-6">
          <Shared.product_card
            :for={product <- @products}
            product={product}
            store={@store}
            quick_add
          />
        </div>
      </div>
    </section>
    <section
      :if={@products == []}
      class="px-4 py-6 sm:px-6 sm:py-8 lg:px-8"
      aria-labelledby="chale-grid-empty-heading"
    >
      <div class="mx-auto max-w-[1280px] border-2 border-dashed border-zinc-400 bg-white px-6 py-16 text-center sm:py-20">
        <h2
          id="chale-grid-empty-heading"
          class="text-2xl font-bold uppercase tracking-tight text-[#101114] [font-family:var(--chale-display)] sm:text-3xl"
        >
          Nothing on the rack yet
        </h2>
        <p class="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-zinc-600">
          {@store.name} hasn't put anything up yet — check back soon.
        </p>
      </div>
    </section>
    """
  end
end
