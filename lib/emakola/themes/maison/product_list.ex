defmodule Emakola.Themes.Maison.ProductList do
  @moduledoc """
  Maison theme product list — shop or collection page.

  Layout:
    * Sticky Maison nav
    * Editorial collection header (centered, large italic serif)
    * Optional category filter row (subtle uppercase links, no chips)
    * Tall portrait_card grid with generous gutters (2/3/4-col)
    * Empty state — single sentence, single ghost link
    * Editorial footer
  """
  use Phoenix.Component

  alias Emakola.Themes.Maison.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :active_category, :map, default: nil
  attr :cart_count, :integer, default: 0
  attr :theme, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <Shared.theme_styles theme={@theme} />
      <Shared.maison_nav store={@store} cart_count={@cart_count} />

      <%!-- Header ── --%>
      <section class="bg-white border-b border-[#E7E5E4]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-20 text-center">
          <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#D4A843)] mb-4">
            {if @active_category, do: "Capsule", else: "The collection"}
          </p>
          <h1
            class="text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] italic leading-[1.05]"
            style="font-family: 'Playfair Display', serif;"
          >
            {category_title(@active_category)}
          </h1>
          <p
            class="mt-3 text-xs sm:text-sm tracking-[0.15em] uppercase text-[#78716C]"
            style="font-family: 'Inter', sans-serif;"
          >
            {result_summary(@products)}
          </p>
        </div>
      </section>

      <%!-- Category links ── --%>
      <section
        :if={@categories != []}
        class="bg-white border-b border-[#E7E5E4] sticky top-[64px] sm:top-[80px] z-40 backdrop-blur-md bg-white/95"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <div class="flex gap-6 sm:gap-8 overflow-x-auto justify-center [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "flex-shrink-0 text-[11px] uppercase tracking-[0.25em] py-2 transition-colors whitespace-nowrap",
                if(is_nil(@active_category),
                  do: "text-[#1C1917] border-b border-[#1C1917]",
                  else: "text-[#78716C] hover:text-[#1C1917] border-b border-transparent"
                )
              ]}
              style="font-family: 'Inter', sans-serif;"
            >
              All
            </a>
            <a
              :for={category <- @categories}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class={[
                "flex-shrink-0 text-[11px] uppercase tracking-[0.25em] py-2 transition-colors whitespace-nowrap",
                if(active?(category, @active_category),
                  do: "text-[#1C1917] border-b border-[#1C1917]",
                  else: "text-[#78716C] hover:text-[#1C1917] border-b border-transparent"
                )
              ]}
              style="font-family: 'Inter', sans-serif;"
            >
              {category.name}
            </a>
          </div>
        </div>
      </section>

      <%!-- Grid ── --%>
      <section class="py-12 sm:py-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <%= if @products == [] do %>
            <div class="py-20 text-center">
              <p
                class="text-2xl sm:text-3xl text-[#1C1917] italic mb-4"
                style="font-family: 'Playfair Display', serif;"
              >
                Between collections.
              </p>
              <p
                class="text-sm text-[#78716C] mb-6 max-w-md mx-auto font-light"
                style="font-family: 'Inter', sans-serif;"
              >
                Subscribe to the private list and we'll let you know the moment the next pieces arrive.
              </p>
              <a
                href="#"
                class="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.25em] text-[#1C1917] border-b border-[#1C1917]/30 pb-1 hover:border-[#1C1917] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Join the list →
              </a>
            </div>
          <% else %>
            <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-8 lg:grid-cols-4 lg:gap-10">
              <Shared.portrait_card
                :for={product <- @products}
                product={product}
                store={@store}
              />
            </div>
          <% end %>
        </div>
      </section>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  defp category_title(nil), do: "Newly arrived"
  defp category_title(%{name: name}) when is_binary(name) and name != "", do: name
  defp category_title(_), do: "Newly arrived"

  defp result_summary([]), do: "Restocking shortly"
  defp result_summary([_]), do: "1 piece"
  defp result_summary(products), do: "#{length(products)} pieces"

  defp active?(_category, nil), do: false
  defp active?(%{slug: slug}, %{slug: active_slug}), do: slug == active_slug
  defp active?(_, _), do: false
end
