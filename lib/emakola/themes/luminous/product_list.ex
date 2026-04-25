defmodule Emakola.Themes.Luminous.ProductList do
  @moduledoc """
  Luminous theme product list — shop or category page.

  Layout:
    * Sticky Luminous nav
    * Editorial collection header (concern as kicker, italic serif h1)
    * Filter chip row (categories) for quick concern switching
    * Beauty card grid (2/3/4-col responsive)
    * Empty state pointing to the routine quiz
    * Beauty-brand footer
  """
  use Phoenix.Component

  alias Emakola.Themes.Luminous.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :active_category, :map, default: nil
  attr :cart_count, :integer, default: 0
  attr :theme, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FFFBF8]">
      <Shared.theme_styles theme={@theme} />
      <Shared.luminous_nav store={@store} cart_count={@cart_count} />

      <%!-- Header ── --%>
      <section class="bg-white border-b border-[#FBCFE8]/40">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14 text-center">
          <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-primary,#DB2777)] mb-3">
            {if @active_category, do: "The collection", else: "All products"}
          </p>
          <h1
            class="text-4xl sm:text-5xl lg:text-6xl text-[#1F1717] italic"
            style="font-family: 'Cormorant Garamond', serif;"
          >
            {category_title(@active_category)}
          </h1>
          <p
            class="mt-3 text-sm text-[#78716C] max-w-md mx-auto"
            style="font-family: 'Inter', sans-serif;"
          >
            {result_summary(@products)}
          </p>
        </div>
      </section>

      <%!-- Filter chips ── --%>
      <section
        :if={@categories != []}
        class="bg-[#FFFBF8] border-b border-[#FBCFE8]/40 sticky top-[57px] sm:top-[65px] z-40 backdrop-blur-md bg-[#FFFBF8]/90"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <div class="flex gap-2 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "flex-shrink-0 inline-flex items-center px-4 py-2 rounded-full text-xs font-medium transition-colors",
                if(is_nil(@active_category),
                  do: "bg-[#1F1717] text-white",
                  else:
                    "bg-white border border-[#FBCFE8] text-[#78716C] hover:border-[var(--theme-primary,#DB2777)]"
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
                "flex-shrink-0 inline-flex items-center px-4 py-2 rounded-full text-xs font-medium transition-colors whitespace-nowrap",
                if(active?(category, @active_category),
                  do: "bg-[#1F1717] text-white",
                  else:
                    "bg-white border border-[#FBCFE8] text-[#78716C] hover:border-[var(--theme-primary,#DB2777)]"
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
      <section class="py-10 sm:py-14">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <%= if @products == [] do %>
            <div class="rounded-3xl border border-dashed border-[#FBCFE8] bg-white p-10 sm:p-16 text-center">
              <span class="material-symbols-outlined text-5xl text-[var(--theme-primary,#DB2777)]/60 mb-4 block">
                spa
              </span>
              <h2
                class="text-3xl text-[#1F1717] mb-2 italic"
                style="font-family: 'Cormorant Garamond', serif;"
              >
                Nothing here yet
              </h2>
              <p
                class="text-sm text-[#78716C] max-w-md mx-auto mb-5"
                style="font-family: 'Inter', sans-serif;"
              >
                Take our 60-second quiz and we'll suggest products tailored to your routine the
                moment they're back in stock.
              </p>
              <a
                href="#"
                class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-[var(--theme-primary,#DB2777)] text-white text-sm font-semibold hover:bg-[#9D174D] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Take the routine quiz
              </a>
            </div>
          <% else %>
            <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
              <Shared.beauty_card
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

  defp category_title(nil), do: "Hand-picked for you"
  defp category_title(%{name: name}) when is_binary(name) and name != "", do: name
  defp category_title(_), do: "Hand-picked for you"

  defp result_summary([]), do: "Restocking soon."
  defp result_summary([_]), do: "1 product"
  defp result_summary(products), do: "#{length(products)} products"

  defp active?(_category, nil), do: false
  defp active?(%{slug: slug}, %{slug: active_slug}), do: slug == active_slug
  defp active?(_, _), do: false
end
