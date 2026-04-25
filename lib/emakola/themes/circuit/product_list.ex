defmodule Emakola.Themes.Circuit.ProductList do
  @moduledoc """
  Circuit theme product list — devices catalog page.
  """
  use Phoenix.Component

  alias Emakola.Themes.Circuit.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :active_category, :map, default: nil
  attr :cart_count, :integer, default: 0
  attr :theme, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0F0F12] text-white">
      <Shared.theme_styles theme={@theme} />
      <Shared.circuit_nav store={@store} cart_count={@cart_count} />

      <%!-- Header ── --%>
      <section class="bg-[#0F0F12] border-b border-[#27272A]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16 text-center">
          <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-accent,#3B82F6)] mb-3">
            {if @active_category, do: "Category", else: "All devices"}
          </p>
          <h1
            class="text-4xl sm:text-5xl lg:text-6xl text-white font-semibold tracking-tight"
            style="font-family: 'Inter', sans-serif;"
          >
            {category_title(@active_category)}
          </h1>
          <p
            class="mt-3 text-sm text-[#9CA3AF]"
            style="font-family: 'Inter', sans-serif;"
          >
            {result_summary(@products)}
          </p>
        </div>
      </section>

      <%!-- Filter chips ── --%>
      <section
        :if={@categories != []}
        class="bg-[#1A1A1F] border-b border-[#27272A] sticky top-[57px] sm:top-[65px] z-40 backdrop-blur-md bg-[#1A1A1F]/95"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <div class="flex gap-2 overflow-x-auto justify-center [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "flex-shrink-0 inline-flex items-center px-4 py-1.5 rounded-full text-xs font-medium transition-colors whitespace-nowrap",
                if(is_nil(@active_category),
                  do: "bg-white text-[#0F0F12]",
                  else: "bg-[#0F0F12] text-[#9CA3AF] hover:text-white border border-[#27272A]"
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
                "flex-shrink-0 inline-flex items-center px-4 py-1.5 rounded-full text-xs font-medium transition-colors whitespace-nowrap",
                if(active?(category, @active_category),
                  do: "bg-white text-[#0F0F12]",
                  else: "bg-[#0F0F12] text-[#9CA3AF] hover:text-white border border-[#27272A]"
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
                class="text-2xl sm:text-3xl text-white font-semibold tracking-tight mb-3"
                style="font-family: 'Inter', sans-serif;"
              >
                No devices in stock
              </p>
              <p
                class="text-sm text-[#9CA3AF] mb-6 max-w-md mx-auto"
                style="font-family: 'Inter', sans-serif;"
              >
                Subscribe and we'll notify you the moment new devices arrive.
              </p>
              <a
                href="#"
                class="inline-flex items-center gap-2 px-6 py-3 bg-[var(--theme-accent,#3B82F6)] text-white text-sm font-semibold rounded-full hover:bg-[#2563EB] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Notify me
              </a>
            </div>
          <% else %>
            <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
              <Shared.device_card
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

  defp category_title(nil), do: "All devices"
  defp category_title(%{name: name}) when is_binary(name) and name != "", do: name
  defp category_title(_), do: "All devices"

  defp result_summary([]), do: "Restocking soon"
  defp result_summary([_]), do: "1 device"
  defp result_summary(products), do: "#{length(products)} devices"

  defp active?(_category, nil), do: false
  defp active?(%{slug: slug}, %{slug: active_slug}), do: slug == active_slug
  defp active?(_, _), do: false
end
