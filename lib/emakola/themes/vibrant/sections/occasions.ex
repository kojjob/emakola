defmodule Emakola.Themes.Vibrant.Sections.Occasions do
  @moduledoc """
  Vibrant occasion edits — the store's root categories as full-bleed tiles.

  Gated by the theme's `categories` toggle, and hidden outright when the shop
  has no categories to show or too few products to need sorting
  (`Emakola.Themes.Layout`: four or more).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [occasion_collection_tile: 1]

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Vibrant.Shared

  @impl true
  def key, do: "vibrant/occasions"

  @impl true
  def label, do: "Occasion edits"

  @impl true
  def settings_schema do
    [
      %{key: "eyebrow", type: :string, label: "Eyebrow", default: ""},
      %{key: "heading", type: :string, label: "Heading", default: "Shop the moments"},
      %{key: "limit", type: :integer, label: "Tiles shown", default: 6}
    ]
  end

  @impl true
  def render(assigns) do
    categories = Map.get(assigns, :categories) || []
    settings = assigns[:settings] || %{}

    # "Curated Edits" claimed someone curated these; they are the store's
    # categories. No eyebrow unless the merchant writes one.
    assigns =
      assigns
      |> assign(:categories, categories)
      |> assign(
        :enabled,
        Shared.section_enabled?(assigns.theme, :categories) and
          Layout.of(assigns).show_categories?
      )
      |> assign(:eyebrow, present(settings["eyebrow"]))
      |> assign(:heading, present(settings["heading"]) || "Shop the moments")
      |> assign(:limit, limit(settings["limit"]))

    ~H"""
    <section :if={@enabled} class="py-10 sm:py-14 bg-[#FFFBEB]" aria-labelledby="vibrant-occasions">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="mb-6 sm:mb-8">
          <p
            :if={@eyebrow}
            class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[var(--theme-primary,#B45309)] mb-2"
          >
            {@eyebrow}
          </p>
          <h2
            id="vibrant-occasions"
            class="text-2xl sm:text-3xl font-bold text-[#1C1917]"
            style="font-family: 'Manrope', sans-serif;"
          >
            {@heading}
          </h2>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5 lg:gap-6">
          <.occasion_collection_tile
            :for={category <- Enum.take(@categories, @limit)}
            category={category}
            store_slug={@store.slug}
          />
        </div>
      </div>
    </section>
    """
  end

  defp limit(value) when is_integer(value) and value > 0, do: value
  defp limit(_value), do: 6

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
