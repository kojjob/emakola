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
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

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
      |> assign(:heading, present(assigns.settings["heading"]))

    ~H"""
    <section :if={@categories != []} class="bg-[color:var(--hl-bg)] pb-24 sm:pb-32">
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
              <div
                aria-hidden="true"
                class="absolute inset-0 bg-gradient-to-t from-black/45 to-transparent opacity-0 motion-safe:transition-opacity group-hover:opacity-100"
              />
              <p class="relative text-xl font-light text-[color:var(--hl-ink)] [font-family:var(--hl-display)] group-hover:text-white">
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
