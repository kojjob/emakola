defmodule Emakola.Themes.Savor.ProductList do
  @moduledoc """
  Savor theme product list — full menu page or category subset.

  Layout:
    * Sticky Savor nav at top
    * Editorial collection header (category name as kicker, conversational h1)
    * Filter chip row (categories) for quick switching
    * Dish-card grid (2/3/4-col responsive)
    * Empty state with WhatsApp call-to-order
    * Restaurant footer
  """
  use Phoenix.Component

  alias Emakola.Themes.Savor.Shared

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
      <Shared.savor_nav store={@store} cart_count={@cart_count} />

      <%!-- Header ── --%>
      <section class="bg-white border-b border-[#FDE68A]/60">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
          <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#DC2626)] mb-2">
            {if @active_category, do: "On the menu", else: "Today's full menu"}
          </p>
          <h1
            class="text-3xl sm:text-4xl lg:text-5xl text-[#1C1917] tracking-wide"
            style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
          >
            {String.upcase(category_title(@active_category))}
          </h1>
          <p class="mt-2 text-sm text-[#78350F]" style="font-family: 'Lora', serif;">
            {result_summary(@products)}
          </p>
        </div>
      </section>

      <%!-- Filter chips ── --%>
      <section
        :if={@categories != []}
        class="bg-[#FFFBEB] border-b border-[#FDE68A]/60 sticky top-[57px] sm:top-[65px] z-40 backdrop-blur-sm bg-[#FFFBEB]/95"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <div class="flex gap-2 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "flex-shrink-0 inline-flex items-center px-4 py-2 rounded-full text-xs font-bold tracking-wide transition-colors",
                if(is_nil(@active_category),
                  do: "bg-[#1C1917] text-white",
                  else: "bg-white border border-[#FDE68A] text-[#78350F] hover:bg-[#FEF3C7]"
                )
              ]}
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              ALL
            </a>
            <a
              :for={category <- @categories}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class={[
                "flex-shrink-0 inline-flex items-center px-4 py-2 rounded-full text-xs font-bold tracking-wide transition-colors whitespace-nowrap",
                if(active?(category, @active_category),
                  do: "bg-[#1C1917] text-white",
                  else: "bg-white border border-[#FDE68A] text-[#78350F] hover:bg-[#FEF3C7]"
                )
              ]}
              style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
            >
              {String.upcase(category.name)}
            </a>
          </div>
        </div>
      </section>

      <%!-- Grid ── --%>
      <section class="py-8 sm:py-12">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <%= if @products == [] do %>
            <div class="rounded-3xl border border-dashed border-[#FDE68A] bg-white p-10 sm:p-16 text-center">
              <span class="material-symbols-outlined text-5xl text-[#D97706] mb-4 block">
                ramen_dining
              </span>
              <h2
                class="text-2xl text-[#1C1917] mb-2 tracking-wide"
                style="font-family: 'Anton', sans-serif; letter-spacing: 0.02em;"
              >
                NOTHING ON THIS MENU YET
              </h2>
              <p
                class="text-sm text-[#78350F] max-w-md mx-auto mb-5"
                style="font-family: 'Lora', serif;"
              >
                Either today's menu hasn't been posted, or this section is between services. Send us a quick message and we'll let you know what's cooking.
              </p>
              <a
                :if={Map.get(@store, :whatsapp_number)}
                href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-[#25D366] text-white text-sm font-semibold hover:bg-[#1FB855] transition-colors"
                style="font-family: 'Lora', serif;"
              >
                <span class="material-symbols-outlined text-[18px]">chat</span> Ask on WhatsApp
              </a>
            </div>
          <% else %>
            <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
              <Shared.dish_card
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

  defp category_title(nil), do: "Full menu"
  defp category_title(%{name: name}) when is_binary(name) and name != "", do: name
  defp category_title(_), do: "Full menu"

  defp result_summary([]), do: "No dishes available right now."
  defp result_summary([_]), do: "1 dish available"
  defp result_summary(products), do: "#{length(products)} dishes available"

  defp active?(_category, nil), do: false
  defp active?(%{slug: slug}, %{slug: active_slug}), do: slug == active_slug
  defp active?(_, _), do: false

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end
end
