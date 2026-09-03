defmodule Emakola.Themes.Fashion.Sections.Lookbook do
  @moduledoc """
  Fashion home lookbook — the 2x2 editorial grid (one cover look, three
  supporting) — extracted verbatim from fashion/home.ex.

  The cover look is the shared plan's featured product and the supporting
  cards are the next three, so a one-product shop shows its product here,
  alone, and the sections below never repeat it.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fashion.Shared
  alias Emakola.Themes.Layout

  @impl true
  def key, do: "fashion/lookbook"

  @impl true
  def label, do: "Lookbook"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    layout = Layout.of(assigns)

    assigns =
      assigns
      |> assign(:lookbook_hero, layout.featured)
      |> assign(:lookbook_supporting, Shared.lookbook_supporting(layout))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :lookbook) && @lookbook_hero}
      class="bg-[#FAF6EE] pb-14 sm:pb-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-8">
          <div>
            <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-2">
              Lookbook
            </p>
            <%!-- "Editor's picks." over the first four products in catalog
                 order. There is no editor and nothing was picked. --%>
            <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-[#1C1917]">
              The lookbook.
            </h2>
          </div>
          <a
            href={store_path(@store.slug, "/products")}
            class="hidden sm:inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-[#5B21B6] hover:gap-3 transition-all"
          >
            See all
            <span class="material-symbols-outlined" style="font-size: 16px;">arrow_forward</span>
          </a>
        </div>

        <div class="grid lg:grid-cols-12 gap-4 sm:gap-6">
          <%!-- Hero product (left, 7 cols; a lone cover sits centred) --%>
          <a
            href={store_path(@store.slug, "/products/#{@lookbook_hero.slug}")}
            class={[
              "relative aspect-[4/5] rounded-lg overflow-hidden group bg-white",
              if(@lookbook_supporting == [],
                do: "lg:col-span-6 lg:col-start-4",
                else: "lg:col-span-7 lg:aspect-auto"
              )
            ]}
          >
            <%= if Shared.first_image(@lookbook_hero) do %>
              <img
                src={Shared.first_image(@lookbook_hero)}
                alt={@lookbook_hero.title}
                class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
              />
            <% else %>
              <div
                class="absolute inset-0 bg-gradient-to-br from-[#5B21B6]/20 to-[#D97706]/15 flex items-center justify-center"
                data-placeholder="product"
              >
                <span class="material-symbols-outlined text-[#5B21B6]/40" style="font-size: 120px;">
                  checkroom
                </span>
              </div>
            <% end %>
            <span class="absolute top-4 left-4 px-3 py-1.5 rounded-full bg-[#D97706] text-white text-[10px] font-bold uppercase tracking-wider">
              Cover Look
            </span>
            <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-[#1C1917] to-transparent p-6 sm:p-8">
              <h3 class="fashion-heading text-2xl sm:text-3xl font-semibold text-white mb-1">
                {@lookbook_hero.title}
              </h3>
              <p class="text-base font-bold text-[#D97706]">
                {EmakolaWeb.Helpers.Currency.format_price(
                  @lookbook_hero.min_price || 0,
                  Map.get(@store, :currency, "GHS")
                )}
              </p>
            </div>
          </a>

          <%!-- 3 stacked supporting (right, 5 cols) --%>
          <div
            :if={@lookbook_supporting != []}
            class="lg:col-span-5 grid grid-cols-3 lg:grid-cols-1 gap-4 sm:gap-6"
          >
            <Shared.product_card
              :for={product <- @lookbook_supporting}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </div>
    </section>
    """
  end
end
