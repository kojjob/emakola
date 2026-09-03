defmodule Emakola.Themes.Heirloom.Sections.CategoryGallery do
  @moduledoc """
  The store's categories as a row of tall cards that scrolls sideways.

  The reference labelled each card with a count — "12 GOODS / Kitchen". That
  count is not rendered here. `Catalog.Category` carries no product-count
  aggregate, and the home page loads only the first eight products, so any
  number computed from what is in scope would be the size of that page
  rather than the size of the category. A wrong number that looks
  authoritative is worse than no number.

  Horizontal scroll is kept on every breakpoint. It is native, costs no
  JavaScript, and is the interaction shoppers on small Android screens
  already expect.

  The gallery joins the page once the stall is full enough to need sorting
  (`Emakola.Themes.Layout`: four or more products). Covers come from the
  store's real category covers (`category_photos`, loaded by `StoreLive`),
  not from the home's own product preview: that preview is what the hero
  card and the showcase already show, and a home must not show the same
  photo twice.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "heirloom/category_gallery"

  @impl true
  def label, do: "Category gallery"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    categories = Map.get(assigns, :categories) || []

    assigns =
      assigns
      |> assign(:categories, categories)
      |> assign(:layout, Layout.of(assigns))
      |> assign(:covers, Map.get(assigns, :category_photos) || %{})
      |> assign(:heading, present(assigns.settings["heading"]))

    ~H"""
    <section
      :if={@categories != [] and @layout.show_categories?}
      class="bg-[color:var(--hl-bg)] pb-24 sm:pb-32"
    >
      <div class="mx-auto max-w-[1360px] px-5 sm:px-8">
        <h2
          :if={@heading}
          class="mb-10 text-2xl font-light tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)] sm:text-3xl"
        >
          {@heading}
        </h2>
      </div>

      <ul class="flex snap-x snap-mandatory gap-4 overflow-x-auto px-5 pb-4 sm:px-8 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        <li
          :for={category <- @categories}
          class="w-[15rem] shrink-0 snap-start sm:w-[19rem]"
        >
          <a
            href={store_path(@store.slug, "/category/#{category.slug}")}
            class="group block focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--hl-accent)] focus-visible:ring-offset-4"
          >
            <div class="relative flex aspect-[3/4] items-end overflow-hidden rounded-[28px] bg-[color:var(--hl-tile)] p-6">
              <.optimized_image
                :if={@covers[category.id]}
                src={@covers[category.id]}
                alt=""
                width={760}
                height={1010}
                class="absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-500 group-hover:scale-[1.04]"
              />
              <div
                aria-hidden="true"
                class={[
                  "absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent",
                  !@covers[category.id] && "hidden"
                ]}
              />
              <p class={[
                "relative text-xl font-light [font-family:var(--hl-display)]",
                if(@covers[category.id],
                  do: "text-white",
                  else: "text-[color:var(--hl-ink)]"
                )
              ]}>
                {category.name}
              </p>
            </div>
          </a>
        </li>
      </ul>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(_other), do: nil
end
