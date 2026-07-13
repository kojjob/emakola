defmodule Emakola.Themes.Fashion.Sections.NewArrivalsBand do
  @moduledoc "Fashion home new-arrivals band (aubergine) — extracted verbatim from fashion/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fashion.Shared

  @impl true
  def key, do: "fashion/new_arrivals_band"

  @impl true
  def label, do: "New arrivals band"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    products = assigns[:products] || []

    assigns = assign(assigns, :new_arrivals, Enum.take(Enum.drop(products, 4), 4))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :new_arrivals_band) && @new_arrivals != []}
      class="bg-[#5B21B6] py-14 sm:py-20 text-[#FAF6EE]"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between mb-8 gap-4">
          <div>
            <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-2">
              Restocked
            </p>
            <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl">
              Back in stock, briefly.
            </h2>
          </div>
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-[var(--theme-accent,#D97706)] text-white text-xs font-bold uppercase tracking-wider hover:bg-[#B45309] transition-colors self-start sm:self-end"
          >
            Shop the Restock
            <span class="material-symbols-outlined" style="font-size: 14px;">arrow_forward</span>
          </a>
        </div>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
          <a
            :for={product <- @new_arrivals}
            href={store_path(@store.slug, "/products/#{product.slug}")}
            class="group block"
          >
            <div class="aspect-[3/4] bg-white/5 ring-1 ring-white/10 overflow-hidden mb-3 rounded-lg">
              <%= if Shared.first_image(product) do %>
                <img
                  src={Shared.first_image(product)}
                  alt={product.title}
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <span class="material-symbols-outlined text-[#D97706]/40" style="font-size: 56px;">
                    checkroom
                  </span>
                </div>
              <% end %>
            </div>
            <h3 class="fashion-heading text-base font-semibold text-white mb-1 line-clamp-1">
              {product.title}
            </h3>
            <p class="text-sm text-[#D97706] font-bold">
              {EmakolaWeb.Helpers.Currency.format_price(
                product.min_price || 0,
                Map.get(@store, :currency, "GHS")
              )}
            </p>
          </a>
        </div>
      </div>
    </section>
    """
  end
end
