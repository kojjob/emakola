defmodule Emakola.Themes.Heritage.ProductList do
  @moduledoc """
  Heritage theme product list — workshop or category page.

  Layout:
    * Sticky Heritage nav
    * Editorial collection header (centered, large Lora serif h1)
    * Optional category filter row (warm uppercase pills)
    * craft_card grid with "Handmade in [city]" badges
    * Empty state with workshop subscribe CTA
    * Heritage footer
  """
  use Phoenix.Component

  alias Emakola.Themes.Heritage.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :active_category, :map, default: nil
  attr :cart_count, :integer, default: 0
  attr :theme, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FFFBEB]">
      <Shared.theme_styles theme={@theme} />
      <Shared.heritage_nav store={@store} cart_count={@cart_count} />

      <%!-- Header ── --%>
      <section class="bg-[#FFFBEB] border-b border-[#E7DDC7]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16 text-center">
          <p class="text-[10px] font-medium tracking-[0.3em] uppercase text-[var(--theme-accent,#84A98C)] mb-3">
            {if @active_category, do: "From the workshop", else: "The collection"}
          </p>
          <h1
            class="text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-[1.05]"
            style="font-family: 'Lora', serif;"
          >
            {category_title(@active_category)}
          </h1>
          <p
            class="mt-3 text-sm text-[#78716C]"
            style="font-family: 'Inter', sans-serif;"
          >
            {result_summary(@products)}
          </p>
        </div>
      </section>

      <%!-- Category pills ── --%>
      <section
        :if={@categories != []}
        class="bg-[#FFFBEB] border-b border-[#E7DDC7] sticky top-[64px] sm:top-[80px] z-40 backdrop-blur-md bg-[#FFFBEB]/95"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <div class="flex gap-2 overflow-x-auto justify-start sm:justify-center [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "flex-shrink-0 inline-flex items-center px-4 py-2 rounded-full text-xs uppercase tracking-[0.15em] transition-all whitespace-nowrap border",
                if(is_nil(@active_category),
                  do:
                    "bg-[var(--theme-primary,#A0522D)] text-white border-[var(--theme-primary,#A0522D)]",
                  else:
                    "bg-white text-[#78716C] border-[#E7DDC7] hover:border-[var(--theme-primary,#A0522D)]"
                )
              ]}
              style="font-family: 'Inter', sans-serif;"
            >
              All pieces
            </a>
            <a
              :for={category <- @categories}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class={[
                "flex-shrink-0 inline-flex items-center px-4 py-2 rounded-full text-xs uppercase tracking-[0.15em] transition-all whitespace-nowrap border",
                if(active?(category, @active_category),
                  do:
                    "bg-[var(--theme-primary,#A0522D)] text-white border-[var(--theme-primary,#A0522D)]",
                  else:
                    "bg-white text-[#78716C] border-[#E7DDC7] hover:border-[var(--theme-primary,#A0522D)]"
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
      <section class="py-12 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <%= if @products == [] do %>
            <div class="py-20 text-center">
              <p
                class="text-2xl sm:text-3xl text-[#1C1917] mb-3"
                style="font-family: 'Lora', serif;"
              >
                Between batches.
              </p>
              <p
                class="text-sm text-[#78716C] mb-6 max-w-md mx-auto"
                style="font-family: 'Inter', sans-serif;"
              >
                Subscribe to the workshop list and we'll let you know when the next pieces are ready.
              </p>
              <a
                href="#"
                class="inline-flex items-center gap-2 px-6 py-3 bg-[var(--theme-primary,#A0522D)] text-white rounded-full text-sm font-medium hover:bg-[#7C3F22] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Subscribe to the workshop
              </a>
            </div>
          <% else %>
            <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-6 lg:grid-cols-4 lg:gap-8">
              <Shared.craft_card
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

  defp category_title(nil), do: "From the workshop"
  defp category_title(%{name: name}) when is_binary(name) and name != "", do: name
  defp category_title(_), do: "From the workshop"

  defp result_summary([]), do: "Restocking shortly"
  defp result_summary([_]), do: "1 piece"
  defp result_summary(products), do: "#{length(products)} pieces"

  defp active?(_category, nil), do: false
  defp active?(%{slug: slug}, %{slug: active_slug}), do: slug == active_slug
  defp active?(_, _), do: false
end
