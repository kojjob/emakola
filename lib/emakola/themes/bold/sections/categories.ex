defmodule Emakola.Themes.Bold.Sections.Categories do
  @moduledoc """
  Bold home category strip — text links separated by vertical bars —
  extracted verbatim from bold/home.ex.

  Nothing here is merchant copy: every label is the store's own category
  name, so the section declares no settings.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Bold.Shared

  @impl true
  def key, do: "bold/categories"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :categories, fn -> [] end)

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :categories) and @categories != []}
      class="py-8 bg-[#F8FAFC] border-b border-[#E2E8F0]"
      aria-label="Product categories"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-center gap-4 sm:gap-6 flex-wrap">
          <a
            href={store_path(@store.slug, "/products")}
            class="text-xs sm:text-sm font-semibold tracking-[0.15em] uppercase text-[#0F172A] hover:text-[#B45309] transition-colors"
            style="font-family: 'Inter', sans-serif;"
          >
            All
          </a>
          <span
            :for={cat <- @categories}
            class="flex items-center gap-4 sm:gap-6"
          >
            <span class="text-[#CBD5E1]" aria-hidden="true">|</span>
            <a
              href={store_path(@store.slug, "/category/#{cat.slug}")}
              class="text-xs sm:text-sm font-semibold tracking-[0.15em] uppercase text-[#64748B] hover:text-[#0F172A] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              {cat.name}
            </a>
          </span>
        </div>
      </div>
    </section>
    """
  end
end
