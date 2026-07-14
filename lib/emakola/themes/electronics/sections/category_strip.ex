defmodule Emakola.Themes.Electronics.Sections.CategoryStrip do
  @moduledoc """
  Electronics home category pill strip -- extracted verbatim from
  electronics/home.ex. The pills come from `@theme.categories_strip.items`
  (a list, so it has no scalar setting the editor could expose).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Item

  @impl true
  def key, do: "electronics/category_strip"
  @impl true
  def label, do: "Category strip"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :strip_items, categories_strip_items(assigns.theme))

    ~H"""
    <%!-- CATEGORY PILL STRIP --%>
    <section
      :if={section_enabled?(@theme, :categories)}
      class="bg-[#F5EFE5] border-b border-[#E5E7EB]"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-5">
        <div class="flex flex-wrap items-center gap-2 sm:gap-3">
          <a
            :for={item <- @strip_items}
            href={store_path(@store.slug, "/products")}
            class={"inline-flex items-center px-4 py-2 rounded-full text-sm font-semibold transition-colors min-h-[40px] " <>
              if(Item.field(item, :active), do: "bg-[var(--theme-primary,#134E4A)] text-white", else: "bg-white border border-[#E5E7EB] text-[#1F2937] hover:border-[#0EA5E9] hover:text-[#134E4A]")}
          >
            {Item.field(item, :label)}
          </a>
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex items-center gap-1 ml-auto text-xs font-semibold text-[#134E4A] hover:gap-2 transition-all"
          >
            See all
            <span class="material-symbols-outlined" style="font-size: 14px;">arrow_forward</span>
          </a>
        </div>
      </div>
    </section>
    """
  end

  defp categories_strip_items(theme) do
    case get_in(theme, [:categories_strip, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_categories_strip()
    end
  end

  defp default_categories_strip do
    [
      %{label: "Wireless", active: true},
      %{label: "Noise Cancellation"},
      %{label: "Sports & Active"},
      %{label: "Phones"}
    ]
  end
end
