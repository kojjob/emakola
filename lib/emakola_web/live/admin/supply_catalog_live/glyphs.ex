defmodule EmakolaWeb.Admin.SupplyCatalogLive.Glyphs do
  @moduledoc """
  The supply catalogue's icon family, shared by the browse grid and the offer
  page: 24×24 box, 1.8 stroke, round caps, no fills, colour inherited from
  whatever tile the glyph sits in.

  Inline SVG rather than the app's `hero-*` mask spans on purpose. These pages
  are read by merchants who read slowly, so an icon carries meaning next to
  almost every fact, and two of these marks (the market tote, the coin stack)
  do not exist in heroicons.

  Metaphors are chosen to be read in a Ghanaian market, not in a design
  system: coins for money a trader keeps, two people for a supplier
  relationship — NOT a chain link, which is a developer's picture of
  "connection".
  """

  use EmakolaWeb, :html

  # Path data only. Every glyph shares the viewBox and stroke treatment, so
  # only the strokes themselves differ between them.
  @glyphs %{
    # a market tote: the product itself, when a supplier gave us no photo
    product: [
      "M6 7h12l1.2 12.1a1.6 1.6 0 0 1-1.6 1.9H6.4a1.6 1.6 0 0 1-1.6-1.9Z",
      "M9 7V5.5a3 3 0 0 1 6 0V7",
      "M9.5 12.5h5M10.6 15.4h2.8"
    ],
    supplier: ["M3 20h18M5 20V9l7-5 7 5v11", "M10 20v-5h4v5"],
    tag: [
      "M20.6 13.4 13 21a2 2 0 0 1-2.8 0l-7-7A2 2 0 0 1 2.6 12.6V4a1.4 1.4 0 0 1 1.4-1.4h8.6a2 2 0 0 1 1.4.6l6.6 6.6a2 2 0 0 1 0 2.8Z"
    ],
    wallet: ["M3 6.6h18a0 0 0 0 1 0 0v12H3Z", "M3 10.6h18", "M16.4 14.6h2"],
    margin: ["M4 17.5 9.5 12l3.4 3.4L20 8.4", "M15.4 8.4H20v4.6"],
    lock: ["M5 10.4h14v9.2H5Z", "M8.4 10.4V7.8a3.6 3.6 0 0 1 7.2 0v2.6"],
    connect: [
      "M5.8 8a3.2 3.2 0 1 0 6.4 0 3.2 3.2 0 1 0-6.4 0",
      "M3.4 19.2a5.6 5.6 0 0 1 11.2 0",
      "M15.1 9.6a2.5 2.5 0 1 0 5 0 2.5 2.5 0 1 0-5 0",
      "M15.4 19.2a5.1 5.1 0 0 1 5.9-4.4"
    ],
    coins: [
      "M5.4 6.6a6.6 2.8 0 1 0 13.2 0 6.6 2.8 0 1 0-13.2 0",
      "M5.4 6.6v4.8c0 1.6 3 2.8 6.6 2.8s6.6-1.2 6.6-2.8V6.6",
      "M5.4 11.4v5c0 1.6 3 2.8 6.6 2.8s6.6-1.2 6.6-2.8v-5"
    ],
    search: ["M4 11a7 7 0 1 0 14 0 7 7 0 1 0-14 0", "m20 20-3.6-3.6"],
    add_to_store: [
      "M4 7.6 12 3.4l8 4.2v8.8L12 20.6 4 16.4Z",
      "M4 7.6 12 12l8-4.4M12 12v5",
      "M17.6 17.4h4.4M19.8 15.2v4.4"
    ],
    dispatch: [
      "M3 5h11v10H3Z",
      "M14 8.6h3.4L21 12.2V15h-7Z",
      "M5.5 17.6a1.9 1.9 0 1 0 3.8 0 1.9 1.9 0 1 0-3.8 0",
      "M15.3 17.6a1.9 1.9 0 1 0 3.8 0 1.9 1.9 0 1 0-3.8 0"
    ],
    area: [
      "M12 21s6.5-5.6 6.5-10.5a6.5 6.5 0 1 0-13 0C5.5 15.4 12 21 12 21Z",
      "M9.6 10.4a2.4 2.4 0 1 0 4.8 0 2.4 2.4 0 1 0-4.8 0"
    ],
    returns: ["M9 14 4.5 9.5 9 5", "M4.5 9.5h9A6 6 0 0 1 19.5 15.5A6 6 0 0 1 13.5 21.5H8"],
    warranty: [
      "M12 3.2 5 6v5.4c0 4.2 2.9 7.6 7 9.4 4.1-1.8 7-5.2 7-9.4V6Z",
      "m9.2 11.8 2 2 3.6-3.8"
    ],
    variant: ["M4 7.6 12 3.4l8 4.2v8.8L12 20.6 4 16.4Z", "M4 7.6 12 12l8-4.4M12 12v8.6"],
    waiting: ["M3 12a9 9 0 1 0 18 0 9 9 0 1 0-18 0", "M12 7v5l3 2"],
    plus: ["M12 5v14M5 12h14"],
    check: ["m4.5 12.75 6 6 9-13.5"],
    back: ["M19 12H5M11 18l-6-6 6-6"]
  }

  @doc """
  Renders one glyph from the family.

  The colour comes from `currentColor`, so a glyph inherits whatever the tile
  around it sets.
  """
  attr :name, :atom, required: true, values: Map.keys(@glyphs)
  attr :class, :string, default: "w-5 h-5"
  attr :stroke_width, :string, default: "1.8"

  def glyph(assigns) do
    assigns = assign(assigns, :paths, Map.fetch!(@glyphs, assigns.name))

    ~H"""
    <svg
      class={@class}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width={@stroke_width}
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path :for={d <- @paths} d={d} />
    </svg>
    """
  end
end
