defmodule Emakola.Themes.Electronics.Sections.Featured do
  @moduledoc """
  Electronics home "Popular product" grid plus the featured-deal split card
  -- extracted verbatim from electronics/home.ex.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Electronics.Shared

  @impl true
  def key, do: "electronics/featured"
  @impl true
  def label, do: "Popular products"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    products = assigns[:products] || []

    assigns =
      assigns
      |> assign(:featured_products, Enum.take(products, 4))
      |> assign(:featured_deal, List.first(products))
      |> assign(:heading, setting(assigns[:settings], "heading", "Popular product"))

    ~H"""
    <%!-- POPULAR PRODUCTS GRID + FEATURED DEAL --%>
    <section
      :if={section_enabled?(@theme, :featured_products) && @featured_products != []}
      class="bg-[#F5EFE5] pb-14 sm:pb-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-end justify-between mb-8">
          <h2 class="electronics-heading text-3xl sm:text-4xl font-extrabold text-[#134E4A]">
            {@heading}
          </h2>
          <a
            href={store_path(@store.slug, "/products")}
            class="hidden sm:inline-flex items-center gap-1 text-sm font-semibold text-[#134E4A] hover:gap-2 transition-all"
          >
            See all
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5">
          <Shared.product_card :for={product <- @featured_products} product={product} store={@store} />
        </div>

        <%!-- Featured deal split card --%>
        <div
          :if={@featured_deal}
          class="mt-8 grid lg:grid-cols-2 gap-0 rounded-2xl overflow-hidden electronics-card"
        >
          <div class="aspect-square lg:aspect-auto bg-[#F3F4F6] flex items-center justify-center p-12">
            <%= if Shared.first_image(@featured_deal) do %>
              <img
                src={Shared.first_image(@featured_deal)}
                alt={@featured_deal.title}
                class="max-w-full max-h-full object-contain"
              />
            <% else %>
              <span class="material-symbols-outlined text-[#134E4A]/30" style="font-size: 160px;">
                headphones
              </span>
            <% end %>
          </div>
          <div class="p-8 sm:p-10 lg:p-12 flex flex-col justify-center">
            <h3 class="electronics-heading text-2xl sm:text-3xl font-bold text-[#1F2937] mb-3">
              {@featured_deal.title}
            </h3>
            <p
              :if={@featured_deal.description}
              class="text-sm text-[#4B5563] leading-relaxed mb-5 line-clamp-3"
            >
              {@featured_deal.description}
            </p>
            <div class="flex items-center justify-between">
              <span class="electronics-mono text-2xl font-bold text-[#134E4A]">
                {EmakolaWeb.Helpers.Currency.format_price(
                  @featured_deal.min_price || 0,
                  Map.get(@store, :currency, "GHS")
                )}
              </span>
              <a
                href={store_path(@store.slug, "/products/#{@featured_deal.slug}")}
                class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-[var(--theme-primary,#134E4A)] text-white text-sm font-bold hover:bg-[#0E3F3B] transition-colors"
              >
                Add to Cart
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
