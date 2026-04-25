defmodule Emakola.Themes.Fade.ProductList do
  @moduledoc """
  Fade theme product list — drops or capsule page. Dark, hard-edged grid.
  """
  use Phoenix.Component

  alias Emakola.Themes.Fade.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :active_category, :map, default: nil
  attr :cart_count, :integer, default: 0
  attr :theme, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0A0A0A] text-[#FAFAFA]">
      <Shared.theme_styles theme={@theme} />
      <Shared.fade_nav store={@store} cart_count={@cart_count} />

      <%!-- Header ── --%>
      <section class="bg-[#0A0A0A] border-b border-[#1F1F1F]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-16">
          <p class="text-[10px] font-bold tracking-[0.3em] uppercase text-[var(--theme-accent,#00FF85)] mb-3">
            {if @active_category, do: "Capsule", else: "Live drops"}
          </p>
          <h1
            class="text-5xl sm:text-6xl lg:text-7xl text-white uppercase tracking-[-0.01em] leading-[0.95]"
            style="font-family: 'Space Grotesk', sans-serif;"
          >
            {category_title(@active_category)}
          </h1>
          <p
            class="mt-3 text-xs uppercase tracking-[0.25em] text-[#A3A3A3]"
            style="font-family: 'Space Grotesk', sans-serif;"
          >
            {result_summary(@products)}
          </p>
        </div>
      </section>

      <%!-- Category links ── --%>
      <section
        :if={@categories != []}
        class="bg-[#0A0A0A] border-b border-[#1F1F1F] sticky top-[57px] sm:top-[65px] z-40"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <div class="flex gap-5 sm:gap-7 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "flex-shrink-0 text-[11px] font-semibold uppercase tracking-[0.25em] py-2 transition-colors whitespace-nowrap border-b-2",
                if(is_nil(@active_category),
                  do: "text-[var(--theme-accent,#00FF85)] border-[var(--theme-accent,#00FF85)]",
                  else: "text-[#A3A3A3] hover:text-white border-transparent"
                )
              ]}
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              All
            </a>
            <a
              :for={category <- @categories}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class={[
                "flex-shrink-0 text-[11px] font-semibold uppercase tracking-[0.25em] py-2 transition-colors whitespace-nowrap border-b-2",
                if(active?(category, @active_category),
                  do: "text-[var(--theme-accent,#00FF85)] border-[var(--theme-accent,#00FF85)]",
                  else: "text-[#A3A3A3] hover:text-white border-transparent"
                )
              ]}
              style="font-family: 'Space Grotesk', sans-serif;"
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
            <div class="py-20 text-center">
              <p
                class="text-3xl sm:text-4xl text-white uppercase tracking-[0.02em] mb-3"
                style="font-family: 'Space Grotesk', sans-serif;"
              >
                Sold out
              </p>
              <p
                class="text-sm text-[#A3A3A3] mb-6 max-w-md mx-auto"
                style="font-family: 'Inter', sans-serif;"
              >
                Subscribe for early access to the next drop — 24h before it goes public.
              </p>
              <a
                href="#"
                class="inline-flex items-center gap-2 px-6 py-3 bg-[var(--theme-accent,#00FF85)] text-[#0A0A0A] text-[11px] font-bold uppercase tracking-[0.25em] hover:bg-[#00CC6A] transition-colors"
                style="font-family: 'Space Grotesk', sans-serif;"
              >
                Get early access
              </a>
            </div>
          <% else %>
            <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 lg:grid-cols-4 lg:gap-5">
              <Shared.drop_card
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

  defp category_title(nil), do: "Live drops"
  defp category_title(%{name: name}) when is_binary(name) and name != "", do: String.upcase(name)
  defp category_title(_), do: "Live drops"

  defp result_summary([]), do: "Restocking · Never"
  defp result_summary([_]), do: "1 piece"
  defp result_summary(products), do: "#{length(products)} pieces"

  defp active?(_category, nil), do: false
  defp active?(%{slug: slug}, %{slug: active_slug}), do: slug == active_slug
  defp active?(_, _), do: false
end
