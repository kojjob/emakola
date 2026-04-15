defmodule Emakola.Themes.Market.Home do
  @moduledoc """
  Market theme — home page renderer.

  Renders the store landing page with category circles, a featured product
  hero card, a product grid, and an about section.
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents,
    only: [
      featured_product_card: 1,
      product_card: 1,
      about_section: 1,
      optimized_image: 1
    ]

  alias Emakola.Themes.Market.Shared

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto">
      <%!-- Story-style category circles --%>
      <nav
        :if={@categories != []}
        class="py-4 bg-white border-b border-[#E2E8F0]"
        aria-label="Product categories"
      >
        <div
          class="flex gap-4 px-4 sm:px-6 lg:px-8 lg:gap-6 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
          role="list"
        >
          <a
            :for={category <- @categories}
            href={"/s/#{@store.slug}/category/#{category.slug}"}
            class="flex flex-col items-center gap-1.5 flex-shrink-0 group"
            role="listitem"
          >
            <div class="w-[68px] h-[68px] rounded-full p-[3px] bg-[#E2E8F0] group-hover:scale-105 transition-transform">
              <%= if Shared.category_image(category) do %>
                <.optimized_image
                  src={Shared.category_image(category)}
                  alt={category.name}
                  priority={:low}
                  class="w-full h-full rounded-full object-cover border-2 border-white"
                  width={62}
                  height={62}
                />
              <% else %>
                <div class="w-full h-full rounded-full bg-[#F1F5F9] border-2 border-white flex items-center justify-center">
                  <span class="text-lg font-semibold text-[#94A3B8]">
                    {String.first(category.name)}
                  </span>
                </div>
              <% end %>
            </div>
            <span class="text-[0.6875rem] font-medium text-[#475569] text-center whitespace-nowrap group-hover:text-[#0F172A]">
              {category.name}
            </span>
          </a>
        </div>
      </nav>

      <%!-- Main content --%>
      <div class="px-4 sm:px-6 lg:px-8 py-4 sm:py-6">
        <%!-- Featured product hero card --%>
        <.featured_product_card :if={@products != []} product={List.first(@products)} store={@store} />

        <%!-- Product grid --%>
        <section :if={@products != []} aria-labelledby="shop-all-heading">
          <h2 id="shop-all-heading" class="text-lg font-bold text-[#0F172A] mb-4">Shop All</h2>
          <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 lg:grid-cols-4 lg:gap-5 mb-10">
            <.product_card :for={product <- @products} product={product} store={@store} />
          </div>
        </section>

        <%!-- About section --%>
        <.about_section store={@store} />
      </div>
    </div>

    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    """
  end
end
