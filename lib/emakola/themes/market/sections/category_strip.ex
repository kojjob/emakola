defmodule Emakola.Themes.Market.Sections.CategoryStrip do
  @moduledoc """
  Market home story-style category circles — Instagram/WhatsApp DNA kept
  deliberately (spec: docs/superpowers/specs/2026-07-12-market-theme-elevation.md).
  Warm stone rings; the hover/focus ring is the merchant's primary colour.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Market.Shared

  @impl true
  def key, do: "market/category_strip"
  @impl true
  def label, do: "Categories"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    # The circle used to show a photograph only when the merchant had set
    # `category.image_url`, which nobody does — so the strip was a row of
    # lettered blanks. The store's real category cover fills it now.
    assigns = assign(assigns, :covers, Map.get(assigns, :category_photos) || %{})

    ~H"""
    <nav
      :if={@categories != []}
      class="border-b border-stone-200 bg-white py-4"
      aria-label="Product categories"
    >
      <div
        class="mx-auto flex max-w-[1280px] gap-4 overflow-x-auto px-4 sm:px-6 lg:gap-6 lg:px-8 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
        role="list"
      >
        <a
          :for={category <- @categories}
          href={store_path(@store.slug, "/category/#{category.slug}")}
          class="group flex flex-shrink-0 flex-col items-center gap-1.5 rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2"
          role="listitem"
        >
          <div class="h-[68px] w-[68px] rounded-full bg-stone-200 p-[3px] group-hover:bg-store-accent group-focus-visible:bg-store-accent motion-safe:transition-[background-color,transform] motion-safe:group-hover:scale-105">
            <% cover = Shared.category_image(category) || Map.get(@covers, category.id) %>
            <%= if cover do %>
              <.optimized_image
                src={cover}
                alt={category.name}
                priority={:low}
                class="h-full w-full rounded-full border-2 border-white object-cover"
                width={62}
                height={62}
              />
            <% else %>
              <div class="flex h-full w-full items-center justify-center rounded-full border-2 border-white bg-gradient-to-br from-stone-50 to-stone-200">
                <span class="text-lg font-semibold text-stone-500 [font-family:var(--dt-heading-font,inherit)]">
                  {String.first(category.name)}
                </span>
              </div>
            <% end %>
          </div>
          <span class="whitespace-nowrap text-center text-[0.6875rem] font-medium text-stone-600 group-hover:text-stone-900">
            {category.name}
          </span>
        </a>
      </div>
    </nav>
    """
  end
end
