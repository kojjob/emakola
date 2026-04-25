defmodule Emakola.Themes.Atlas.ProductList do
  @moduledoc """
  Atlas theme product list — sidebar-led catalog with breadcrumb header
  and color-coded shelf grid.
  """
  use Phoenix.Component

  alias Emakola.Themes.Atlas.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, default: []
  attr :active_category, :map, default: nil
  attr :cart_count, :integer, default: 0
  attr :theme, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAFAFA] text-[#0F172A]">
      <Shared.theme_styles theme={@theme} />
      <Shared.atlas_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <div class="flex">
        <Shared.sidebar
          store={@store}
          categories={@categories}
          active_category={@active_category}
        />

        <div class="flex-1 min-w-0">
          <main class="max-w-[1100px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-10">
            <%!-- Breadcrumb ── --%>
            <nav
              class="flex items-center gap-2 mb-5 text-sm text-[#64748B]"
              style="font-family: 'Inter', sans-serif;"
              aria-label="Breadcrumb"
            >
              <a href={"/s/#{@store.slug}"} class="hover:text-[#0F172A] transition-colors">
                {@store.name}
              </a>
              <span class="text-[#CBD5E1]">/</span>
              <span class="text-[#0F172A] font-medium">{category_title(@active_category)}</span>
            </nav>

            <div class="flex items-end justify-between mb-6">
              <div>
                <h1
                  class="text-2xl sm:text-3xl font-bold text-[#0F172A]"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {category_title(@active_category)}
                </h1>
                <p
                  class="mt-1 text-sm text-[#64748B] tabular-nums"
                  style="font-family: 'JetBrains Mono', monospace;"
                >
                  {result_summary(@products)}
                </p>
              </div>
            </div>

            <%= if @products == [] do %>
              <div class="rounded-2xl border border-dashed border-[#CBD5E1] bg-white p-12 text-center">
                <span class="material-symbols-outlined text-5xl text-[#94A3B8] mb-4 block">
                  inventory_2
                </span>
                <p
                  class="text-base font-semibold text-[#0F172A] mb-2"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Nothing here right now
                </p>
                <p
                  class="text-sm text-[#64748B] max-w-md mx-auto"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Try a different branch in the sidebar or visit our full catalog.
                </p>
              </div>
            <% else %>
              <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 sm:gap-4">
                <Shared.shelf_card
                  :for={{product, idx} <- Enum.with_index(@products)}
                  product={product}
                  store={@store}
                  color_index={idx}
                  swatches={["#0F172A", "#475569", "#0EA5E9"]}
                />
              </div>
            <% end %>
          </main>
        </div>
      </div>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  defp category_title(nil), do: "All products"
  defp category_title(%{name: name}) when is_binary(name) and name != "", do: name
  defp category_title(_), do: "All products"

  defp result_summary([]), do: "0 items"
  defp result_summary([_]), do: "1 item"
  defp result_summary(products), do: "#{length(products)} items"
end
