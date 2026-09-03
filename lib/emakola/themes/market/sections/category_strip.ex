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

  alias Emakola.Themes.Market.{Layout, Shared}

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
    assigns =
      assigns
      |> assign(:covers, Map.get(assigns, :category_photos) || %{})
      |> assign(:layout, Layout.of(assigns))

    ~H"""
    <nav
      :if={@categories != [] and @layout.show_categories?}
      class="bg-white py-3.5"
      aria-label="Product categories"
    >
      <div
        class="mx-auto flex max-w-[1280px] gap-2.5 overflow-x-auto px-4 sm:px-6 lg:px-8 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
        role="list"
      >
        <a
          :for={category <- @categories}
          href={store_path(@store.slug, "/category/#{category.slug}")}
          class="group flex flex-shrink-0 items-center gap-2.5 rounded-full border border-stone-200 bg-stone-50 py-1.5 pl-1.5 pr-4 hover:border-store-accent hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
          role="listitem"
        >
          <% cover = Shared.category_image(category) || Map.get(@covers, category.id) %>
          <%!-- A chip without a cover is a plain chip: a lettered circle is
               nothing to a buyer who reads slowly. --%>
          <%= if cover do %>
            <.optimized_image
              src={cover}
              alt={category.name}
              priority={:low}
              class="h-9 w-9 rounded-full object-cover"
              width={36}
              height={36}
            />
          <% else %>
            <span class="block h-9 w-2" aria-hidden="true"></span>
          <% end %>
          <span class="whitespace-nowrap text-[0.8125rem] font-bold text-stone-700 group-hover:text-stone-900">
            {category.name}
          </span>
        </a>
      </div>
    </nav>
    """
  end
end
